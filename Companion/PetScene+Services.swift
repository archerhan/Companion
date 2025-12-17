//
//  PetScene+Services.swift
//  Companion
//
//  Created by it on 2025/12/15.
//


import SpriteKit
import Cocoa

extension PetScene {
    
    // MARK: - 喝水提醒服务
    func startWaterReminderTimer() {
        waterTimer?.invalidate()
        
        // 【新增】双重检查：如果配置是关闭的，直接不启动
        if !AppConfig.enableWaterReminder {
            print("🚫 喝水提醒已关闭，定时器不启动")
            return
        }
        
        let interval = AppConfig.waterInterval
        self.currentWaterInterval = interval
        print("💧 喝水提醒已启动，间隔: \(interval)秒")
        
        waterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerWaterReminder()
        }
    }
    
    func triggerWaterReminder() {
        print("🥤 触发喝水提醒")
        for pet in pets {
            if case .environment = pet.currentState {
                continue
            }
            pet.triggerSystemEvent(.waterReminder)
        }
    }
    
    // MARK: - 整点报时服务
    func checkHourlyChime() {
        
        // 【新增】如果在 update 循环中检测到开关关闭，直接返回
        // 这里使用缓存变量 isHourlyChimeEnabled 以提高性能 (每帧读取内存比读取 UserDefaults 快)
        if !isHourlyChimeEnabled { return }

        
        let date = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else { return }
        
        if minute == 0 && hour != lastChimeHour {
            triggerHourlyChime()
            lastChimeHour = hour
        }
    }
    
    func triggerHourlyChime() {
        print("🔔 触发整点报时")
        for pet in pets {
            if case .environment = pet.currentState { continue }
            pet.triggerSystemEvent(.hourlyChime)
        }
    }
    
    // MARK: - 番茄钟服务
    
    func startPomodoro(durationMinutes: Double = AppConfig.pomodoroDuration) {
        if isFocusing {
            print("⚠️ 已经在专注状态中，忽略本次请求")
            return
        }
        print("⏰ 开始番茄钟: \(durationMinutes)分钟")
        
        isFocusing = true
        focusEndTime = Date().addingTimeInterval(durationMinutes * 60)
        
        for pet in pets {
            pet.isPomodoroActive = true
            pet.startFocusMode()
        }
        
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFocusStatus()
        }
        checkFocusStatus()
    }
    
    func checkFocusStatus() {
        guard let endTime = focusEndTime else { return }
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            stopPomodoro()
            // 【修改】检查音效配置
            if AppConfig.enableSound {
                NSSound(named: "Glass")?.play()
            }
            return
        }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        for pet in pets {
            pet.updateFocusTimerBubble(text: timeString)
        }
    }
    
    func stopPomodoro() {
        print("⏰ 番茄钟结束")
        isFocusing = false
        focusTimer?.invalidate()
        focusTimer = nil
        focusEndTime = nil
        
        for pet in pets {
            pet.isPomodoroActive = false
            if case .system(.focusMode) = pet.currentState {
                pet.endFocusMode()
            }
            pet.endFocusMode() // 确保清理路径
        }
    }
    
    // MARK: - 右键菜单逻辑
    
    func showFocusMenu(for pet: PetSpriteNode, event: NSEvent) {
        let menu = NSMenu(title: "Pet Menu")
        
        // ─── 分支 A: 正在专注模式中 ───
        if isFocusing {
            // 1. 显示剩余时间 (不可点击)
            if let endTime = focusEndTime {
                let remaining = endTime.timeIntervalSinceNow
                let minutes = Int(remaining) / 60
                // 优化文案显示
                let title = remaining > 0
                    ? "menu_focus_active_format".localized(with: minutes)
                    : "menu_focus_ending".localized
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false // 仅展示，不可点
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // 2. 结束专注选项
            let stopItem = NSMenuItem(title: "menu_focus_stop".localized, action: #selector(stopFocusFromMenu), keyEquivalent: "")
            stopItem.target = self
            stopItem.representedObject = pet
            menu.addItem(stopItem)
            
        }
        // ─── 分支 B: 未在专注模式 (新增功能) ───
        else {
            // 动态获取当前设置的时长，让菜单文字更准确
            let duration = Int(AppConfig.pomodoroDuration)
            let startItem = NSMenuItem(title: "menu_focus_start_format".localized(with: duration), action: #selector(startFocusFromMenu(_:)), keyEquivalent: "")
            startItem.target = self
            startItem.representedObject = pet
            menu.addItem(startItem)
        }
        
        // 弹出菜单
        NSMenu.popUpContextMenu(menu, with: event, for: self.view!)
    }
    
    // MARK: - 菜单响应动作
        
    @objc private func startFocusFromMenu(_ sender: NSMenuItem) {
        // 直接读取配置中的时长启动
        startPomodoro(durationMinutes: AppConfig.pomodoroDuration)
    }
    
    // (原有的 stopFocusFromMenu 保持不变)
    @objc private func stopFocusFromMenu(_ sender: NSMenuItem) {
        stopPomodoro()
    }
    
    // Debug 接口
    func triggerWindyWeather() {
        pets.forEach { $0.triggerWind() }
    }
}
