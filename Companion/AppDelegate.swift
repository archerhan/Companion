//
//  AppDelegate.swift
//  Companion
//
//  Created by it on 2025/12/6.
//


import Cocoa

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
        menu.addItem(NSMenuItem(title: "整点报时", action: #selector(timeCheme), keyEquivalent: "t"))
        statusItem?.menu = menu
    }
    
    @objc func timeCheme() {
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // todo
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
}

