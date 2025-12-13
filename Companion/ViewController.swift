
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
        self.view.wantsLayer = true
        self.skView.wantsLayer = true
        self.skView.allowsTransparency = true
        
        if let view = self.skView {
            let scene = PetScene(size: view.bounds.size)
            scene.scaleMode = .resizeFill
            scene.backgroundColor = .clear
//            scene.viewController = self
            
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
        window.level = .statusBar
        window.setFrame(screen.frame, display: true, animate: false)
        window.acceptsMouseMovedEvents = true
        
        // 2. 修正场景尺寸
        if scene.size != screen.frame.size {
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
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
        self.view.window?.ignoresMouseEvents = false
    }
}
