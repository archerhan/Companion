
//
//  ViewController.swift
//  Companion
//

import Cocoa
import SpriteKit

class ViewController: NSViewController {

    var skView: SKView!
    
    private var petTrackingArea: NSTrackingArea?
    private var debugLayer: CALayer?
    
    override func loadView() {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let view = SKView(frame: frame)
        view.wantsLayer = true
        view.allowsTransparency = true
        self.view = view
        self.skView = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let view = self.skView {
            let scene = PetScene(size: view.bounds.size)
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            // 【核心优化】
            // 1. 限制帧率为 30。这会极大降低 CPU 占用。
            // 对于像素风或简单动画，甚至可以设为 15-24。
            view.preferredFramesPerSecond = 30
            // 【新增优化】
            // 1. 忽略同级顺序 (如果不需要 zPosition 排序)
            view.ignoresSiblingOrder = true
            
            // 2. 剔除不可见节点 (虽然对全屏透明帮助有限，但有益无害)
            view.shouldCullNonVisibleNodes = true
            // 2. 允许 SpriteKit 异步渲染，避免阻塞主线程
            view.isAsynchronous = true
            #if DEBUG
            view.showsFPS = true
            view.showsNodeCount = true
            #endif
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        guard let screen = NSScreen.main,
              let scene = skView.scene as? PetScene else { return }
        if scene.size != screen.frame.size {
            scene.size = screen.frame.size
        }
    }
}
