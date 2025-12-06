
//
//  ViewController.swift
//  Companion
//

import Cocoa
import SpriteKit

class ViewController: NSViewController {

    @IBOutlet var skView: SKView!
    
    private var petTrackingArea: NSTrackingArea?
    private var debugLayer: CALayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.skView.wantsLayer = true
        self.skView.allowsTransparency = true
        
        if let view = self.skView {
            // 使用 view.bounds.size 创建场景，即使此时尺寸不正确也无妨，
            // 因为 viewDidAppear 中会立即修正它。
            print("--- viewDidLoad --- 场景初始尺寸: \(view.bounds.size)")
            let scene = PetScene(size: view.bounds.size)
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
            scene.viewController = self
            
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            #if DEBUG
            view.showsFPS = true
            view.showsNodeCount = true
            #endif
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // viewDidAppear 是配置窗口和场景尺寸的最佳时机
        configureWindowAndScene()
    }
    
    private func configureWindowAndScene() {
        guard let window = self.view.window,
              let screen = NSScreen.main,
              let scene = skView.scene as? PetScene else { return }
        
        // 1. 配置窗口
        window.styleMask = .borderless
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.setFrame(screen.frame, display: true, animate: false)
        window.acceptsMouseMovedEvents = true
        
        print("--- 打印当前各种尺寸 ---\n")
        print("window:\(window.frame)\n")
        print("SceneView:\(skView.frame)\n")
        print("PetScene:\(scene.frame)\n")
        
        // 2. 修正场景尺寸
        if scene.size != screen.frame.size {
            print("--- viewDidAppear --- 修正场景尺寸从 \(scene.size) 到 \(screen.frame.size)")
            scene.size = screen.frame.size
        }
    }
    
    func updateTrackingArea(for petNode: SKSpriteNode) {
        guard let scene = self.skView.scene else { return }
        
        let petFrameInScene = petNode.calculateAccumulatedFrame()
        let bottomLeftInView = skView.convert(petFrameInScene.origin, from: scene)
        let topRightInView = skView.convert(CGPoint(x: petFrameInScene.maxX, y: petFrameInScene.maxY), from: scene)
        
        let trackingRect = CGRect(
            x: bottomLeftInView.x,
            y: bottomLeftInView.y,
            width: topRightInView.x - bottomLeftInView.x,
            height: topRightInView.y - bottomLeftInView.y
        )
        
        if let oldTrackingArea = self.petTrackingArea {
            skView.removeTrackingArea(oldTrackingArea)
        }
        
        let newTrackingArea = NSTrackingArea(rect: trackingRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        skView.addTrackingArea(newTrackingArea)
        self.petTrackingArea = newTrackingArea
        
//        #if DEBUG
//        debugLayer?.removeFromSuperlayer()
//        let newDebugLayer = CALayer()
//        newDebugLayer.frame = trackingRect
//        newDebugLayer.borderColor = NSColor.red.cgColor
//        newDebugLayer.borderWidth = 1.0
//        skView.layer?.addSublayer(newDebugLayer)
//        self.debugLayer = newDebugLayer
//        #endif
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
        self.view.window?.ignoresMouseEvents = false
    }
}
