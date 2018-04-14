//
//  ConnectViewController.swift
//  pkimport
//
//  Created by YUN YOUNG LEE on 2018. 3. 24..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import NetworkExtension

class ConnectViewController: UIViewController {
    @IBOutlet weak var connectLabel: UILabel!
    @IBOutlet weak var loadingLabel: UILabel!
    
    var appDelegate: AppDelegate {
        get {
            return UIApplication.shared.delegate as! AppDelegate
        }
    }
    
    private var rework = false
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: .main) { (notification) in
            if self.rework {
                self.rework = false
                self.startWork()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startWork()
    }
    
    func startWork() {
        if appDelegate.state == .LoadList {
            loadList()
        } else {
            loadProps()
        }
        updateUI()
    }
    
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: NSLocalizedString("NOT CONNECTED", comment: "alert title"), message: "\(message)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Open Settings", comment: "alert button"), style: .default) { (action) in
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
                self.rework = true
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Retry", comment: "alert button"), style: .default) { (action) in
                self.loadProps()
                self.updateUI()
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func updateUI() {
        if appDelegate.state == .Connect {
            connectLabel.text = NSLocalizedString("Connecting to Camera", comment: "main state text")
            connectLabel.alpha = 0.5
            startBlink(label: connectLabel)
            finishBlink(label: loadingLabel)
            loadingLabel.alpha = 0.5
        } else if appDelegate.state == .LoadList {
            connectLabel.text = Camera.shared.props?.model
            finishBlink(label: connectLabel)
            loadingLabel.alpha = 0.5
            startBlink(label: loadingLabel)
        }
    }
    
    func loadProps() {
        appDelegate.state = .Connect
        
        Camera.shared.loadProperties { (props, error) in
            let ud = UserDefaults.standard
            
            if error != nil {
                print("load prop error: \(error!)")
                #if !arch(x86_64)
                if let ssid = ud.string(forKey: "lastSSID"), let key = ud.string(forKey: "lastKey") {
                    let config = NEHotspotConfiguration(ssid: ssid, passphrase: key, isWEP: false)
                    NEHotspotConfigurationManager.shared.apply(config, completionHandler: { (error) in
                        if let heerr = error as NSError? {
                            print("hotspot error: \(error!)")
                            if heerr.domain == "NEHotspotConfigurationErrorDomain" {
                                switch heerr.code {
                                case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                                    fallthrough
                                case NEHotspotConfigurationError.pending.rawValue:
                                    self.loadProps()
                                    return
                                default:
                                    break
                                }
                            }
                            self.showError(NSLocalizedString("Not connected to Camera's Wi-Fi.\nGo to Settings > Wi-Fi and select your camera's SSID.", comment: "connect error message"))
                        } else {
                            self.loadProps()
                        }
                    })
                    
                    return
                }
                #endif
                
                self.showError(NSLocalizedString("Not connected to Camera's Wi-Fi.\nGo to Settings > Wi-Fi and select your camera's SSID.", comment: "connect error message"))
                return
            }
            
            ud.set(props!.ssid, forKey: "lastSSID")
            ud.set(props!.key, forKey: "lastKey")
            ud.synchronize()
            
            DispatchQueue.main.async {
                self.loadList()
                self.updateUI()
            }
        }
    }
    
    func loadList() {
        appDelegate.state = .LoadList
        
        Camera.shared.loadList { (photos, error) in
            if error != nil {
                print("list error: \(error!)")
                self.showError(NSLocalizedString("Error occured in load photos list.\nGo to Settings > Wi-Fi and confirm connected to your camera.", comment: "loading photo list error message"))
                return
            }
            
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "CloseConnect", sender: nil)
            }
        }
    }
    
    // MARK: - Effect
    
    func startBlink(label: UILabel) {
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse], animations: {
            label.alpha = 1
        }, completion: nil)
    }
    
    func finishBlink(label: UILabel) {
        label.layer.removeAllAnimations()
        label.alpha = 1
    }
    
}
