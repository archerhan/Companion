//
//  AppDelegate.swift
//  Companion
//
//  Created by it on 2025/12/6.
//


import Cocoa
import SpriteKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    // 引用设置窗口控制器，防止被释放
    private var settingsWindowController: NSWindowController?
    
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
            // 确保不开启阴影（透明窗口的阴影计算非常耗费 CPU）
            window.hasShadow = false
            // 确保背景色是纯透明，而不是半透明
            window.backgroundColor = NSColor.clear
            window.level = .statusBar
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
        
        // 添加设置入口
        menu.addItem(NSMenuItem(title: "menu_settings".localized, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "menu_test_chime".localized, action: #selector(timeCheme), keyEquivalent: "t"))
        statusItem?.menu = menu
        
        menu.addItem(NSMenuItem(title: "menu_test_water".localized, action: #selector(testWater), keyEquivalent: "d"))
        statusItem?.menu = menu
        
        menu.addItem(NSMenuItem(title: "menu_test_wind".localized, action: #selector(testWind), keyEquivalent: "w"))
        statusItem?.menu = menu
        
        let duration = Int(AppConfig.pomodoroDuration)
        let defaultFocusTitle = "menu_focus_start_format".localized(with: duration)
        menu.addItem(NSMenuItem(title: defaultFocusTitle, action: #selector(startFocus), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "menu_quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    // MARK: - 打开设置窗口
    @objc func openSettings() {
        // 1. 检查窗口是否已经存在
        if let windowController = settingsWindowController, let window = windowController.window {
            // 如果窗口已存在，将其置于最前并获取焦点
            window.makeKeyAndOrderFront(nil)
            // 这一点很关键：对于菜单栏应用，必须显式激活应用，窗口才会真正浮在其他应用（如浏览器）上面
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 2. 如果不存在，则创建新窗口
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "宠物偏好设置"
        // 样式：标题栏 + 可关闭 + 可最小化
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        
        // 设置为 false，这样关闭窗口时对象不会立即销毁，而是由我们将 controller 置 nil 来释放
        // 配合下面的 Notification 使用
        window.isReleasedWhenClosed = false
        
        let windowController = NSWindowController(window: window)
        self.settingsWindowController = windowController
        
        // 3. 监听窗口关闭事件
        // 当用户点击左上角 X 关闭窗口时，将 settingsWindowController 置为 nil
        // 这样下次点击菜单时，第 1 步检查就会失败，从而进入第 2 步创建新窗口
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] _ in
            self?.settingsWindowController = nil
        }
        
        // 4. 显示窗口并激活应用
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

