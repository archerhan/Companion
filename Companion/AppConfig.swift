//
//  AppConfig.swift
//  Companion
//
//  Created by it on 2025/12/17.
//

import Foundation

struct AppConfig {
    // MARK: - Keys
    private enum Keys {
        static let enableSound = "cfg_enableSound"
        static let waterInterval = "cfg_waterInterval"
        static let pomodoroDuration = "cfg_pomodoroDuration"
        
        // 【新增】
        static let enableWaterReminder = "cfg_enableWaterReminder"
        static let enableHourlyChime = "cfg_enableHourlyChime"
    }
    
    // MARK: - Accessors (供游戏逻辑读取)
    
    /// 是否开启音效
    static var enableSound: Bool {
        // 默认 true
        UserDefaults.standard.object(forKey: Keys.enableSound) == nil ? true : UserDefaults.standard.bool(forKey: Keys.enableSound)
    }
    
    /// 是否开启喝水提醒
    static var enableWaterReminder: Bool {
        // 默认开启 (true)
        UserDefaults.standard.object(forKey: Keys.enableWaterReminder) == nil ? true : UserDefaults.standard.bool(forKey: Keys.enableWaterReminder)
    }
    
    /// 是否开启整点报时
    static var enableHourlyChime: Bool {
        // 默认开启 (true)
        UserDefaults.standard.object(forKey: Keys.enableHourlyChime) == nil ? true : UserDefaults.standard.bool(forKey: Keys.enableHourlyChime)
    }
    
    /// 喝水提醒间隔 (秒)
    static var waterInterval: TimeInterval {
        let val = UserDefaults.standard.double(forKey: Keys.waterInterval)
        return val > 0 ? val : 2700 // 默认 45分钟 (2700秒)
    }
    
    /// 番茄钟时长 (分钟)
    static var pomodoroDuration: Double {
        let val = UserDefaults.standard.double(forKey: Keys.pomodoroDuration)
        return val > 0 ? val : 25.0 // 默认 25分钟
    }
}
