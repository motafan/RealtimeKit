//
//  AppDelegate.swift
//  UIKitDemo
//
//  Created by Sondra on 8/27/25.
//

import UIKit
import RealtimeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize RealtimeKit
        setupRealtimeKit()
        
        return true
    }
    
    private func setupRealtimeKit() {
        // Configure RealtimeManager with Mock provider for demo
        let config = RealtimeConfiguration(
            provider: .mock,
            appId: "demo_app_id",
            enableLogging: true
        )
        
        Task {
            do {
                try await RealtimeManager.shared.configure(with: config)
            } catch {
                print("Failed to configure RealtimeManager: \(error)")
            }
        }
        
        // Setup localization
        _ = LocalizationManager.shared.detectSystemLanguage()
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

