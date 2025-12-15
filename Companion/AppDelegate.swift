//
//  AppDelegate.swift
//  Companion
//
//  Created by it on 2025/12/6.
//


import Cocoa
import SpriteKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupWindow()
        setupStatusBar()
    }
    
    // 配置窗口全屏/无边框/透明
    private func setupWindow() {
        if let window = NSApplication.shared.windows.first {
            window.styleMask = .borderless
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.acceptsMouseMovedEvents = true
            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true, animate: false)
            }
            window.ignoresMouseEvents = false
        }
    }
    
    private func setupStatusBar() {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cat", accessibilityDescription: nil)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: NSLocalizedString("common_exit", comment: "退出登录"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(NSMenuItem(title: "测试: 整点报时", action: #selector(timeCheme), keyEquivalent: "t"))
        statusItem?.menu = menu
        
        menu.addItem(NSMenuItem(title: "测试: 喝水提醒", action: #selector(testWater), keyEquivalent: "d"))
        statusItem?.menu = menu
        
        menu.addItem(NSMenuItem(title: "测试: 被风吹起", action: #selector(testWind), keyEquivalent: "w"))
        statusItem?.menu = menu
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "开始专注 (25分钟)", action: #selector(startFocus), keyEquivalent: "f"))
        statusItem?.menu = menu
    }
    
    @objc func testWater() {
        guard let window = NSApplication.shared.windows.first,
              let view = window.contentView as? SKView,
              let scene = view.scene as? PetScene else { return }
        
        scene.triggerWaterReminder()
    }
    
    @objc func timeCheme() {
        guard let window = NSApplication.shared.windows.first,
              let view = window.contentView as? SKView,
              let scene = view.scene as? PetScene else { return }
        
        scene.triggerHourlyChime()
    }
    
    @objc func testWind() {
        guard let window = NSApplication.shared.windows.first,
              let view = window.contentView as? SKView,
              let scene = view.scene as? PetScene else { return }
        
        scene.triggerWindyWeather()
    }
    
    @objc func startFocus() {
        guard let window = NSApplication.shared.windows.first,
              let view = window.contentView as? SKView,
              let scene = view.scene as? PetScene else { return }
        
        scene.startPomodoro(durationMinutes: 25)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // todo
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
}

