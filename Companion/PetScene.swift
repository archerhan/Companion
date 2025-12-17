//
//  PetScene.swift
//  Companion
//
//  Created by it on 2025/12/15.
//
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
    private var lastInteractionCheckTime: TimeInterval = 0
    // 【新增】缓存配置状态，避免每帧读取 UserDefaults
    internal var currentWaterInterval: TimeInterval = 0
    internal var isWaterReminderEnabled: Bool = true // 缓存喝水开关
    internal var isHourlyChimeEnabled: Bool = true   // 缓存报时开关

    
    // MARK: - 生命周期
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
        
        addPet(config: CatBlackConfiguration())
        lastChimeHour = Calendar.current.component(.hour, from: Date())
        // 启动时，记录当前配置
        // 1. 初始化读取配置
        currentWaterInterval = AppConfig.waterInterval
        isWaterReminderEnabled = AppConfig.enableWaterReminder
        isHourlyChimeEnabled = AppConfig.enableHourlyChime
        
        startWaterReminderTimer() // 定义在 +Services
        
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        for pet in pets {
            pet.update(deltaTime: deltaTime)
        }
        
        // 2. 【核心优化】限制鼠标检测频率
        // 每 0.1 秒检测一次即可 (即 10 FPS)
        if currentTime - lastInteractionCheckTime > 0.1 {
            updateWindowInteraction()
            lastInteractionCheckTime = currentTime
        }
        checkHourlyChime() // 定义在 +Services
    }
    
    override func willMove(from view: SKView) {
        waterTimer?.invalidate()
        focusTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userDefaultsDidChange() {
        // --- 处理喝水提醒逻辑 ---
        let newInterval = AppConfig.waterInterval
        let newWaterEnabled = AppConfig.enableWaterReminder
        
        // 情况 A: 开关状态变了
        if newWaterEnabled != isWaterReminderEnabled {
            print("⚙️ 喝水开关变更: \(newWaterEnabled)")
            isWaterReminderEnabled = newWaterEnabled
            
            if newWaterEnabled {
                startWaterReminderTimer() // 开启 -> 启动
            } else {
                waterTimer?.invalidate()  // 关闭 -> 销毁
                waterTimer = nil
            }
        }
        // 情况 B: 开关没变(且是开着的)，但时间间隔变了
        else if newWaterEnabled && abs(newInterval - currentWaterInterval) > 0.1 {
            print("⚙️ 喝水间隔变更，重启定时器...")
            currentWaterInterval = newInterval
            startWaterReminderTimer() // 重启
        }
        
        // --- 处理整点报时逻辑 ---
        let newChimeEnabled = AppConfig.enableHourlyChime
        if newChimeEnabled != isHourlyChimeEnabled {
            print("⚙️ 报时开关变更: \(newChimeEnabled)")
            isHourlyChimeEnabled = newChimeEnabled
            // 报时是在 update 中检查的，只要更新变量即可，不需要重启 Timer
        }
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
                // 只要宠物当前状态允许交互，就可以打开右键菜单
                if pet.currentState.canInteract {
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
    }
    
    private func endDrag(pet: PetSpriteNode, velocity: CGPoint) {
        draggedPet = nil
        lastDragLocation = nil
        dragOffset = .zero
        pet.endDrag(velocity: velocity)
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
