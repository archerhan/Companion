import SpriteKit
import Cocoa

class PetScene: SKScene {
    
    // MARK: - 属性
    var pets: [PetSpriteNode] = []
    
    // 拖拽相关
    var draggedPet: PetSpriteNode?
    var dragOffset: CGPoint = .zero
    var lastDragLocation: CGPoint?
    var lastDragTime: TimeInterval = 0
    
    // 时间控制
    var lastUpdateTime: TimeInterval = 0
    var lastChimeHour: Int = -1
    
    // 计时器引用
    var waterTimer: Timer?
    var focusTimer: Timer?
    var focusEndTime: Date?
    var isFocusing: Bool = false
    
    // MARK: - 生命周期
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
        
        addPet(config: CatBlackConfiguration())
        lastChimeHour = Calendar.current.component(.hour, from: Date())
        
        startWaterReminderTimer() // 定义在 +Services
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        for pet in pets {
            pet.update(deltaTime: deltaTime)
        }
        
        updateWindowInteraction()
        checkHourlyChime() // 定义在 +Services
    }
    
    override func willMove(from view: SKView) {
        waterTimer?.invalidate()
        focusTimer?.invalidate()
    }
    
    // MARK: - 宠物增删
    
    func addPet(config: PetConfiguration) {
        let pet = PetSpriteNode(configuration: config)
        let minX = pet.size.width
        let maxX = self.size.width - pet.size.width
        pet.position = CGPoint(x: CGFloat.random(in: minX...maxX), y: pet.size.height / 2)
        addChild(pet)
        pets.append(pet)
    }
    
    func removePet(_ pet: PetSpriteNode) {
        pet.removeFromParent()
        if let index = pets.firstIndex(of: pet) {
            pets.remove(at: index)
        }
    }
    
    // MARK: - 鼠标事件
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        
        for pet in pets.reversed() {
            if pet.contains(location) {
                if pet.tryRescue() { return }
                
                if case .system(.focusMode) = pet.currentState { return }
                
                if pet.currentState.canInteract {
                    startDrag(pet: pet, location: location)
                    return
                }
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let pet = draggedPet else { return }
        let location = event.location(in: self)
        
        if let lastLoc = lastDragLocation {
            let deltaX = location.x - lastLoc.x
            pet.updateDragFacing(deltaX: deltaX)
        }
        
        pet.position = CGPoint(x: location.x - dragOffset.x, y: location.y - dragOffset.y)
        lastDragLocation = location
        lastDragTime = event.timestamp
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let pet = draggedPet else { return }
        
        var velocity = CGPoint.zero
        let currentLocation = event.location(in: self)
        
        if let lastLoc = lastDragLocation, (event.timestamp - lastDragTime) < 0.1 {
            let dx = currentLocation.x - lastLoc.x
            let dy = currentLocation.y - lastLoc.y
            let speedX = (dx * 10).clamped(to: -800...800)
            let speedY = (dy * 10).clamped(to: -800...800)
            velocity = CGPoint(x: speedX, y: speedY)
        }
        
        endDrag(pet: pet, velocity: velocity)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        for pet in pets {
            if pet.contains(location) {
                if case .system(.focusMode) = pet.currentState {
                    showFocusMenu(for: pet, event: event)
                    return
                }
            }
        }
        super.rightMouseDown(with: event)
    }
    
    // MARK: - 交互辅助
    
    private func startDrag(pet: PetSpriteNode, location: CGPoint) {
        draggedPet = pet
        dragOffset = CGPoint(x: location.x - pet.position.x, y: location.y - pet.position.y)
        lastDragLocation = location
        lastDragTime = ProcessInfo.processInfo.systemUptime
        pet.startDrag()
        pet.run(SKAction.scale(to: 1.1, duration: 0.1))
    }
    
    private func endDrag(pet: PetSpriteNode, velocity: CGPoint) {
        draggedPet = nil
        lastDragLocation = nil
        dragOffset = .zero
        
        let currentSign = pet.xScale > 0 ? 1.0 : -1.0
        pet.endDrag(velocity: velocity)
        
        let restoreScale = SKAction.scaleX(to: 1.0 * currentSign, y: 1.0, duration: 0.1)
        pet.run(restoreScale)
    }
    
    private func updateWindowInteraction() {
        guard let window = self.view?.window, let view = self.view else { return }
        
        if draggedPet != nil {
            if window.ignoresMouseEvents { window.ignoresMouseEvents = false }
            NSCursor.closedHand.set()
            return
        }
        
        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream
        let mouseLocationInView = view.convert(mouseLocationInWindow, from: nil)
        let mouseLocationInScene = self.convertPoint(fromView: mouseLocationInView)
        
        var isHoveringInteractivePet = false
        for pet in pets {
            if pet.frame.contains(mouseLocationInScene) && pet.currentState.canInteract {
                isHoveringInteractivePet = true
                break
            }
        }
        
        if isHoveringInteractivePet {
            if window.ignoresMouseEvents { window.ignoresMouseEvents = false }
            NSCursor.openHand.set()
        } else {
            if !window.ignoresMouseEvents { window.ignoresMouseEvents = true }
            NSCursor.arrow.set()
        }
    }
}
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
