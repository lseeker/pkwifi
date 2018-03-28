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
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        if appDelegate.state == .LoadList {
            loadList()
        } else {
            loadProps()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }
    
    func showError(_ message: String, _ error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "ERROR", message: "\(message)\n\(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { (action) in
                self.loadProps()
                self.updateUI()
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func updateUI() {
        if appDelegate.state == .Connect {
            connectLabel.text = "Connecting to Camera"
            startBlink(label: connectLabel)
            finishBlink(label: loadingLabel)
            loadingLabel.alpha = 0.5
        } else if appDelegate.state == .LoadList {
            connectLabel.text = Camera.shared.props?.model
            finishBlink(label: connectLabel)
            startBlink(label: loadingLabel)
        }
    }
    
    func loadProps() {
        appDelegate.state = .Connect
        
        Camera.shared.loadProperties { (props, error) in
            let ud = UserDefaults.standard
            
            if let err = error {
                if let ssid = ud.string(forKey: "lastSSID"), let key = ud.string(forKey: "lastKey") {
                    let config = NEHotspotConfiguration(ssid: ssid, passphrase: key, isWEP: false)
                    NEHotspotConfigurationManager.shared.apply(config, completionHandler: { (error) in
                        if let heerr = error as NSError? {
                            var showErr = error!
                            if heerr.domain == "NEHotspotConfigurationErrorDomain" {
                                switch heerr.code {
                                case NEHotspotConfigurationError.userDenied.rawValue:
                                    showErr = err
                                case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                                    fallthrough
                                case NEHotspotConfigurationError.pending.rawValue:
                                    self.loadProps()
                                    return
                                default:
                                    break
                                }
                            }
                            self.showError("Cannot connect to Camera.\nPlease confirm Wi-Fi network connected to Camera.", showErr)
                        } else {
                            self.loadProps()
                        }
                    })
                    
                    return
                }
                
                self.showError("Cannot connect to Camera.", err)
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
            if let err = error {
                self.showError("Cannot load list of Photos", err)
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
