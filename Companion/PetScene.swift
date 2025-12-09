// PetScene.swift
import SpriteKit

class PetScene: SKScene {
    weak var viewController: ViewController?
    
    // 改为宠物数组
    private var pets: [PetSpriteNode] = []
    
    // 当前拖拽相关属性
    private var draggedPet: PetSpriteNode?
    private var dragOffset: CGPoint = .zero
    private var lastKnownPetFrames: [CGRect] = []
    private var dragStartLocation: CGPoint?
    
    private var lastUpdateTime: TimeInterval = 0
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        // 可以创建多个宠物
        addPet()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vc = self.viewController else { return }
            self.pets.forEach { pet in
                vc.updateTrackingArea(for: pet)
            }
        }
    }
    
    private func addPet() {
        let WIDTH_RANGE: ClosedRange<Double> = 0...self.size.width
        let pet = PetSpriteNode(imageNamed: "cat_black_idle-0")
        pet.position = CGPoint(x: Double.random(in: WIDTH_RANGE), y: pet.size.height/2)
        self.addChild(pet)
        pets.append(pet)
        lastKnownPetFrames.append(pet.frame)
    }
    
    override func update(_ currentTime: TimeInterval) {
        updateMouseInteraction()
        
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // 更新所有宠物
        for pet in pets {
            pet.update(deltaTime: deltaTime)
        }
    }
    
    private func updateMouseInteraction() {
        guard let window = self.view?.window, let skView = self.view else { return }
        
        // 检查是否有正在被拖拽的宠物
        if let draggedPet = draggedPet, draggedPet.petState == .beingDragged {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
            return
        }
        
        // 检查鼠标是否在任何宠物上
        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream
        let mouseLocationInView = skView.convert(mouseLocationInWindow, from: nil)
        let mouseLocationInScene = self.convertPoint(fromView: mouseLocationInView)
        
        var isMouseOnAnyPet = false
        
        for pet in pets {
            if pet.contains(mouseLocationInScene) {
                // 检查宠物是否处于特殊状态
                let specialStates: [PetState] = [.sleeping, .eating, .angry, .falling]
                if !specialStates.contains(pet.petState) {
                    isMouseOnAnyPet = true
                    break
                }
            }
        }
        
        if isMouseOnAnyPet {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
        } else {
            window.ignoresMouseEvents = true
            NSCursor.arrow.set()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInScene = event.location(in: self)
        
        // 检查点击到了哪个宠物
        for pet in pets {
            if pet.handleMouseDown(at: locationInScene, event: event) {
                if pet.petState == .beingDragged {
                    draggedPet = pet
                    dragOffset = CGPoint(x: locationInScene.x - pet.position.x,
                                         y: locationInScene.y - pet.position.y)
                    dragStartLocation = locationInScene
                }
                return // 只处理一个宠物
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let pet = draggedPet, pet.petState == .beingDragged else { return }
        
        let newLocation = event.location(in: self)
        var newPosition = CGPoint(
            x: newLocation.x - dragOffset.x,
            y: newLocation.y - dragOffset.y
        )
        
        // 边界限制
        let petHalfWidth = pet.size.width / 2
        let petHalfHeight = pet.size.height / 2
        
        let minX = petHalfWidth
        let maxX = self.size.width - petHalfWidth
        newPosition.x = max(minX, min(newPosition.x, maxX))
        
        let minY = petHalfHeight
        let maxY = self.size.height - petHalfHeight
        newPosition.y = max(minY, min(newPosition.y, maxY))
        
        pet.position = newPosition
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let pet = draggedPet, pet.petState == .beingDragged else { return }
        
        // 计算抛出速度
        if let lastDragLocation = dragStartLocation {
            let currentLoc = event.location(in: self)
            let totalDragDistanceX = currentLoc.x - lastDragLocation.x
            let dragThreshold: CGFloat = 10.0
            
            if totalDragDistanceX > dragThreshold {
                pet.petHorizontalSpeed = abs(pet.petHorizontalSpeed)
            } else if totalDragDistanceX < -dragThreshold {
                pet.petHorizontalSpeed = -abs(pet.petHorizontalSpeed)
            }
            
            pet.petVelocity.y = -100
            pet.petState = .falling
        }
        
        // 重置追踪变量
        dragStartLocation = nil
        draggedPet = nil
        
        // 添加弹性动画
        let currentXScaleSign = pet.xScale.sign == .minus ? -1.0 : 1.0
        let scaleUp = SKAction.scaleX(to: 1.05 * currentXScaleSign, y: 1.05, duration: 0.1)
        let scaleDown = SKAction.scaleX(to: 1.0 * currentXScaleSign, y: 1.0, duration: 0.1)
        pet.run(SKAction.sequence([scaleUp, scaleDown]))
    }
    
    override func didFinishUpdate() {
        guard let viewController = self.viewController else { return }
        
        // 更新所有宠物的追踪区域
        for (index, pet) in pets.enumerated() {
            let currentPetFrame = pet.frame
            if index >= lastKnownPetFrames.count || lastKnownPetFrames[index] != currentPetFrame {
                DispatchQueue.main.async {
                    viewController.updateTrackingArea(for: pet)
                }
                if index < lastKnownPetFrames.count {
                    lastKnownPetFrames[index] = currentPetFrame
                } else {
                    lastKnownPetFrames.append(currentPetFrame)
                }
            }
        }
    }
}
