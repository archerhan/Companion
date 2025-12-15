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
        // 2700秒 = 45分钟
        waterTimer = Timer.scheduledTimer(withTimeInterval: 2700, repeats: true) { [weak self] _ in
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
    
    func startPomodoro(durationMinutes: Double = 25) {
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
            NSSound(named: "Glass")?.play()
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
        
        if let endTime = focusEndTime {
            let remaining = endTime.timeIntervalSinceNow
            let minutes = Int(remaining) / 60
            let title = remaining > 0 ? "专注中... (剩余 \(minutes)分钟)" : "专注中..."
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        
        let stopItem = NSMenuItem(title: "结束专注", action: #selector(stopFocusFromMenu), keyEquivalent: "")
        stopItem.target = self
        stopItem.representedObject = pet
        menu.addItem(stopItem)
        
        NSMenu.popUpContextMenu(menu, with: event, for: self.view!)
    }
    
    @objc private func stopFocusFromMenu(_ sender: NSMenuItem) {
        stopPomodoro()
    }
    
    // Debug 接口
    func triggerWindyWeather() {
        pets.forEach { $0.triggerWind() }
    }
}
