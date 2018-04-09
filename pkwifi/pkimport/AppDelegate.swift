//
//  AppDelegate.swift
//  pkwifi
//
//  Created by YUN YOUNG LEE on 2018. 1. 7..
//  Copyright © 2018년 YUN YOUNG LEE. All rights reserved.
//

import UIKit
import UserNotifications

enum AppState: Int, Codable {
    case Launch
    case Connect
    case LoadList
    case Select
    case Import
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var backgroundCompletionHandler: (() -> Void)?
    var state = AppState.Launch
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        application.applicationIconBadgeNumber = 0
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        coder.encode(state.rawValue, forKey: "AppState")
        if state == .Select {
            coder.encode(Date().timeIntervalSinceReferenceDate, forKey: "SaveTime")
        }
        return state.rawValue >= AppState.LoadList.rawValue
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        state = AppState(rawValue: coder.decodeInteger(forKey: "AppState")) ?? .Launch
        
        if state == .Select {
            let saveTime = Date(timeIntervalSinceReferenceDate: coder.decodeDouble(forKey: "SaveTime"))
            if saveTime.timeIntervalSinceNow < -600 { // 10 minutes
                state = .Launch
                return false
            }
        }
        
        if state.rawValue >= AppState.LoadList.rawValue {
            do {
                try Camera.shared.loadFromFile(withPhotoList: state != .LoadList)
            } catch {
                debugPrint(error)
                state = .Launch
                return false
            }
            return true
        }
        
        state = .Launch
        return false
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        debugPrint("handleEventsForBackgroundURLSession called: \(completionHandler)")
        backgroundCompletionHandler = completionHandler
    }
}
