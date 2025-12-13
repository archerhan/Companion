//
//  BubbleNode.swift
//  Companion
//
//  Created by it on 2025/12/13.
//

import SpriteKit

class BubbleNode: SKNode {
    private let label: SKLabelNode
    private let background: SKShapeNode
    
    override init() {
        // 1. 创建标签
        label = SKLabelNode(fontNamed: "Menlo-Bold") // 或 "PingFang SC"
        label.fontSize = 12
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.zPosition = 101
        
        // 2. 创建背景 (圆角矩形)
        background = SKShapeNode()
        background.fillColor = .white
        background.strokeColor = .black
        background.lineWidth = 1
        background.zPosition = 100
        
        super.init()
        
        addChild(background)
        addChild(label)
        
        // 默认隐藏
        alpha = 0
        isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func show(text: String, at point: CGPoint) {
        // 更新文字
        label.text = text
        
        // 根据文字大小动态调整背景
        let padding: CGFloat = 8
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let rect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        
        background.path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        
        // 设置位置 (通常在头顶)
        self.position = point
        self.isHidden = false
        self.alpha = 0
        self.setScale(0.5)
        
        // 弹出动画
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
        let group = SKAction.group([fadeIn, scaleUp])
        
        // 如果正在显示，先移除旧动作
        removeAllActions()
        run(group)
    }
    
    func hide() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
        let group = SKAction.group([fadeOut, scaleDown])
        
        run(group) {
            self.isHidden = true
        }
    }
}
