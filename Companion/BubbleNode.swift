//
//  BubbleNode.swift
//  Companion
//
//  Created by it on 2025/12/13.
//

import SpriteKit

class BubbleNode: SKNode {
    // 1. 新增一个容器节点，用于承载内容并执行缩放动画
    private let contentNode: SKNode
    private let label: SKLabelNode
    private let background: SKShapeNode
    
    override init() {
        // 初始化容器
        contentNode = SKNode()
        
        // 初始化标签
        label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 18
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.zPosition = 101
        
        // 初始化背景
        background = SKShapeNode()
        background.fillColor = .white
        background.strokeColor = .black
        background.lineWidth = 1
        background.zPosition = 100
        
        super.init()
        
        // 2. 这里的层级关系变了：
        // self -> contentNode -> (background, label)
        addChild(contentNode)
        contentNode.addChild(background)
        contentNode.addChild(label)
        
        // 默认隐藏
        alpha = 0
        isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func show(text: String, at point: CGPoint) {
        label.text = text
        
        let padding: CGFloat = 8
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let rect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        
        background.path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        
        self.position = point
        self.isHidden = false
        self.alpha = 0
        
        // 3. 【关键修改】
        // 动画作用于 contentNode，而不是 self。
        // 这样 self.xScale 可以保持为 -1 (用于抵消父节点的翻转)，
        // 而 contentNode.xScale 可以从 0.5 变大到 1.0 (实现弹出效果)，互不冲突。
        contentNode.setScale(0.5)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        // 这里的 scale(to: 1.0) 只会把 contentNode 变成 1.0，不会影响 self 的翻转
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.2)
        _ = SKAction.group([fadeIn, scaleUp])
        
        // 移除旧动作并运行新动作 (注意是 contentNode 运行缩放，self 运行淡入)
        removeAllActions()
        contentNode.removeAllActions()
        
        self.run(fadeIn)
        contentNode.run(scaleUp)
    }
    
    // 【新增】用于高频更新文字，不播放弹出动画
    func updateText(_ text: String) {
        label.text = text
        
        // 重绘背景 path
        let padding: CGFloat = 8
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let rect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        background.path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        
        // 确保显示
        self.isHidden = false
        self.alpha = 1.0
        
        // 【重要】这里不要修改 self.position，也不要 run SKAction
        // 位置由 PetSpriteNode 控制，缩放由 show() 控制
    }
    
    func hide() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
        
        self.run(fadeOut) {
            self.isHidden = true
        }
        contentNode.run(scaleDown)
    }
}
