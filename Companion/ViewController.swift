
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
