
//
//  PetScene.swift
//  Companion
//

import SpriteKit

class PetScene: SKScene {
    
    weak var viewController: ViewController?
    private var pet: PetSpriteNode!
    private var isDraggingPet = false
    private var dragOffset: CGPoint = .zero
    
    public var isDragging: Bool {
        return isDraggingPet
    }
    
    private var lastKnownPetFrame: CGRect?
    private var petHorizontalSpeed: CGFloat = 100.0
    private var lastUpdateTime: TimeInterval = 0
    private var dragStartLocation: CGPoint?
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        
        pet = PetSpriteNode(imageNamed: "cat_black_walk-0")
        pet.name = "desktopPet"
        pet.size = CGSize(width: 80, height: 80)
        pet.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // 使用 self.size 来设置初始位置，确保与场景尺寸一致
        pet.position = CGPoint(x: self.size.width / 2, y: 200)
        self.addChild(pet)
        
        pet.startWalking()
        updatePetDirection()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vc = self.viewController, let petNode = self.pet else { return }
            vc.updateTrackingArea(for: petNode)
            self.lastKnownPetFrame = petNode.frame
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        updateMouseInteraction()
        
        guard !isDraggingPet else {
            lastUpdateTime = 0
            return
        }
        
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        let petHalfWidth = pet.size.width / 2
        
        // 关键：始终使用 self.size.width 作为边界
        if (pet.position.x - petHalfWidth <= 0 && petHorizontalSpeed < 0) ||
           (pet.position.x + petHalfWidth >= self.size.width && petHorizontalSpeed > 0) {
            petHorizontalSpeed *= -1
            updatePetDirection()
        }
        
        pet.position.x += petHorizontalSpeed * CGFloat(deltaTime)
    }
    
    private func updateMouseInteraction() {
        guard let window = self.view?.window, let skView = self.view else { return }
        if isDraggingPet {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
            return
        }
        
        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream
        let mouseLocationInView = skView.convert(mouseLocationInWindow, from: nil)
        let mouseLocationInScene = self.convertPoint(fromView: mouseLocationInView)
        let isMouseOnPet = pet.frame.contains(mouseLocationInScene)
        if isMouseOnPet {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
        } else {
            window.ignoresMouseEvents = true
            NSCursor.arrow.set()
        }
    }
    
    private func updatePetDirection() {
        if petHorizontalSpeed > 0 {
            pet.xScale = abs(pet.xScale)
        } else {
            pet.xScale = -abs(pet.xScale)
        }
    }
    
    override func didFinishUpdate() {
        guard let petNode = self.pet, let viewController = self.viewController else {
            return
        }
        
        let currentPetFrame = petNode.frame
        if lastKnownPetFrame == nil || lastKnownPetFrame != currentPetFrame {
            DispatchQueue.main.async {
                viewController.updateTrackingArea(for: petNode)
            }
            self.lastKnownPetFrame = currentPetFrame
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDraggingPet {
            isDraggingPet = false
            dragOffset = .zero
            pet.alpha = 1.0
            
            // --- 核心修复：使用 dragStartLocation 进行判断 ---
            if let startLoc = dragStartLocation {
                let currentLoc = event.location(in: self)
                let totalDragDistanceX = currentLoc.x - startLoc.x
                
                // 设置一个更大的阈值，以区分真正的“拖拽”和“点击”
                let dragThreshold: CGFloat = 10.0
                
                print("拖拽距离: \(totalDragDistanceX)")

                if totalDragDistanceX > dragThreshold {
                    // 明确向右拖拽
                    petHorizontalSpeed = abs(petHorizontalSpeed)
                    print("判断为向右拖拽")
                } else if totalDragDistanceX < -dragThreshold {
                    // 明确向左拖拽
                    petHorizontalSpeed = -abs(petHorizontalSpeed)
                    print("判断为向左拖拽")
                }
                // 如果拖拽距离很小 (在阈值内), 则不改变方向，视为点击或微小移动
                
                updatePetDirection() // 根据新的速度方向更新宠物朝向
            }
            
            // 重置追踪变量
            dragStartLocation = nil
            
            // 动画代码
            let currentXScaleSign = pet.xScale.sign == .minus ? -1.0 : 1.0
            let scaleUp = SKAction.scaleX(to: 1.05 * currentXScaleSign, y: 1.05, duration: 0.1)
            let scaleDown = SKAction.scaleX(to: 1.0 * currentXScaleSign, y: 1.0, duration: 0.1)
            pet.run(SKAction.sequence([scaleUp, scaleDown]))
            
            print("结束拖动宠物，新速度方向: \(petHorizontalSpeed > 0 ? "向右" : "向左")")
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInScene = event.location(in: self)
        if atPoint(locationInScene).name == "desktopPet" {
            dragOffset = CGPoint(x: locationInScene.x - pet.position.x, y: locationInScene.y - pet.position.y)
            isDraggingPet = true
            pet.alpha = 0.8
            pet.wasPoked()
            
            dragStartLocation = locationInScene
        }
    }
    
    
    override func mouseDragged(with event: NSEvent) {
        if isDraggingPet {
            let newLocation = event.location(in: self)
            var newPosition = CGPoint(
                x: newLocation.x - dragOffset.x,
                y: newLocation.y - dragOffset.y
            )
            
            // --- 核心修复：添加边界限制 ---
            let petHalfWidth = pet.size.width / 2
            let petHalfHeight = pet.size.height / 2
            
            // 限制水平位置
            let minX = petHalfWidth
            let maxX = self.size.width - petHalfWidth
            newPosition.x = max(minX, min(newPosition.x, maxX))
            
            // 限制垂直位置
            let minY = petHalfHeight
            let maxY = self.size.height - petHalfHeight
            newPosition.y = max(minY, min(newPosition.y, maxY))
            
            // --- 直接设置位置，而不是用 SKAction ---
            pet.position = newPosition
        }
    }
}

