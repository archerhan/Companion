//
//  BubbleNode.swift
//  Companion
//
//  Created by it on 2025/12/6.
//
import SpriteKit

class BubbleNode: SKNode {
    private let contentNode: SKNode
    private let label: SKLabelNode
    private let background: SKShapeNode
    
    override init() {
        contentNode = SKNode()
        
        label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 16
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.zPosition = 101
        
        background = SKShapeNode()
        background.fillColor = .white
        background.strokeColor = .black
        background.lineWidth = 1
        background.zPosition = 100
        
        super.init()
        
        addChild(contentNode)
        contentNode.addChild(background)
        contentNode.addChild(label)
        
        alpha = 0
        isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func show(text: String, at point: CGPoint) {
        updateBackground(text: text)
        
        self.position = point
        self.isHidden = false
        self.alpha = 0
        
        // 动画只作用于 contentNode，保持 self.xScale 可以响应翻转
        contentNode.setScale(0.5)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
        
        removeAllActions()
        contentNode.removeAllActions()
        
        self.run(fadeIn)
        contentNode.run(scaleUp)
    }
    
    func updateText(_ text: String) {
        // 【修复】先移除所有之前的动画（例如 fadeOut），
        // 防止之前的 hide() 动画还在运行中覆盖了 alpha 属性，或者 completion block 导致再次隐藏。
        self.removeAllActions()
        contentNode.removeAllActions()
        
        updateBackground(text: text)
        self.isHidden = false
        self.alpha = 1.0
        contentNode.setScale(1.0) // 确保是全尺寸
    }
    
    func hide() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
        
        self.run(fadeOut) {
            self.isHidden = true
        }
        contentNode.run(scaleDown)
    }
    
    private func updateBackground(text: String) {
        label.text = text
        let padding: CGFloat = 8
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let rect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        background.path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    }
}
