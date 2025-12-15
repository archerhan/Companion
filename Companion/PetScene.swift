import SpriteKit
import Cocoa

class PetScene: SKScene {
    
    // MARK: - 属性
    
    // 宠物集合
    private var pets: [PetSpriteNode] = []
    
    // 拖拽状态记录
    private var draggedPet: PetSpriteNode?
    private var dragOffset: CGPoint = .zero
    private var lastDragLocation: CGPoint? // 用于计算抛掷速度
    private var lastDragTime: TimeInterval = 0
    
    // 时间控制
    private var lastUpdateTime: TimeInterval = 0
    // 报时记录
    private var lastChimeHour: Int = -1
    
    // MARK: - 生命周期
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
        
        // 添加初始宠物
        addPet(config: CatBlackConfiguration())
        // 初始化上次报时为当前小时，防止打开软件瞬间触发
        lastChimeHour = Calendar.current.component(.hour, from: Date())
        
        // 延迟 2 秒后自动触发一次，测试效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//            self?.triggerHourlyChime()
            self?.triggerWindyWeather()
        }

    }
    
    // MARK: - 宠物管理
    
    func addPet(config: PetConfiguration) {
        let pet = PetSpriteNode(configuration: config)
        
        // 随机出生位置 (屏幕底部范围)
        let minX = pet.size.width
        let maxX = self.size.width - pet.size.width
        pet.position = CGPoint(x: CGFloat.random(in: minX...maxX), y: pet.size.height / 2)
        
        self.addChild(pet)
        pets.append(pet)
    }
    
    func removePet(_ pet: PetSpriteNode) {
        pet.removeFromParent()
        if let index = pets.firstIndex(of: pet) {
            pets.remove(at: index)
        }
    }
    
    // MARK: - 核心循环 (Update Loop)
    
    override func update(_ currentTime: TimeInterval) {
        // 1. 计算 Delta Time
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // 2. 更新所有宠物的内部逻辑 (AI + 物理)
        for pet in pets {
            pet.update(deltaTime: deltaTime)
        }
        
        // 3. 处理鼠标穿透逻辑 (核心体验)
        updateWindowInteraction()
        
        // 检查整点报时
        checkHourlyChime()
    }
    
    private func checkHourlyChime() {
        let date = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        
        guard let hour = components.hour, let minute = components.minute else { return }
        
        // 逻辑：如果是 0 分，且这个小时还没报过时
        if minute == 0 && hour != lastChimeHour {
            triggerHourlyChime()
            lastChimeHour = hour
        }
    }
    
    // MARK: - 交互系统 (Mouse Handling)
    
    /// 管理窗口的鼠标穿透状态
    /// 当鼠标悬停在可交互宠物上时，窗口捕获事件；否则窗口忽略事件（点击穿透到桌面）
    private func updateWindowInteraction() {
        guard let window = self.view?.window, let view = self.view else { return }
        
        // 1. 如果正在拖拽，必须捕获鼠标
        if draggedPet != nil {
            if window.ignoresMouseEvents { window.ignoresMouseEvents = false }
            NSCursor.closedHand.set()
            return
        }
        
        // 2. 检测鼠标位置下的宠物
        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream
        let mouseLocationInView = view.convert(mouseLocationInWindow, from: nil)
        let mouseLocationInScene = self.convertPoint(fromView: mouseLocationInView)
        
        var isHoveringInteractivePet = false
        
        for pet in pets {
            // 简单的包围盒检测 (也可以用 pet.contains，但要注意透明区域)
            if pet.frame.contains(mouseLocationInScene) {
                // 只有当宠物处于可交互状态时 (例如被风吹时不可交互)
                if pet.currentState.canInteract {
                    isHoveringInteractivePet = true
                    break
                }
            }
        }
        
        // 3. 动态切换窗口属性
        if isHoveringInteractivePet {
            if window.ignoresMouseEvents { window.ignoresMouseEvents = false }
            NSCursor.openHand.set() // 悬停手势
        } else {
            if !window.ignoresMouseEvents { window.ignoresMouseEvents = true }
            NSCursor.arrow.set() // 恢复普通箭头
        }
    }
    
    // MARK: - 鼠标事件 (Event Handling)
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        
        // 倒序遍历，优先点上面的
        for pet in pets.reversed() {
            if pet.contains(location) {
                
                // 1. 优先尝试解救
                if pet.tryRescue() {
                    // 播放一个音效或反馈
                    // run(SKAction.playSoundFileNamed("rescue.wav", waitForCompletion: false))
                    print("🎉 成功解救宠物！")
                    return
                }
                
                // 2. 如果不是解救，再检查是否可交互并开始拖拽
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
        
        // 计算位移差：当前位置 - 上一次的位置
        if let lastLoc = lastDragLocation {
            let deltaX = location.x - lastLoc.x
            
            // 告诉宠物鼠标在往哪边动
            pet.updateDragFacing(deltaX: deltaX)
        }
        
        // 更新宠物位置
        pet.position = CGPoint(x: location.x - dragOffset.x, y: location.y - dragOffset.y)
        
        // 记录位置用于下一帧计算
        lastDragLocation = location
        lastDragTime = event.timestamp
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let pet = draggedPet else { return }
        
        // 计算抛掷速度 (Throw Physics)
        var velocity = CGPoint.zero
        let currentLocation = event.location(in: self)
        
        // 如果最后一次拖拽发生在极短时间内，则计算速度
        if let lastLoc = lastDragLocation, (event.timestamp - lastDragTime) < 0.1 {
            // 简单的物理公式：速度 = 距离 / 时间
            // 乘系数调节手感
            let dx = currentLocation.x - lastLoc.x
            let dy = currentLocation.y - lastLoc.y
            
            // 限制最大速度防止飞出宇宙
            let speedX = (dx * 10).clamped(to: -800...800)
            let speedY = (dy * 10).clamped(to: -800...800)
            
            velocity = CGPoint(x: speedX, y: speedY)
        }
        
        endDrag(pet: pet, velocity: velocity)
    }
    
    // MARK: - 拖拽逻辑辅助
    
    private func startDrag(pet: PetSpriteNode, location: CGPoint) {
        draggedPet = pet
        dragOffset = CGPoint(x: location.x - pet.position.x, y: location.y - pet.position.y)
        lastDragLocation = location
        lastDragTime = ProcessInfo.processInfo.systemUptime
        
        // 通知宠物节点进入拖拽状态 (停止AI，播放被拎起来的动画)
        pet.startDrag()
        
        // 简单的弹簧效果
        pet.run(SKAction.scale(to: 1.1, duration: 0.1))
    }
    
    private func endDrag(pet: PetSpriteNode, velocity: CGPoint) {
        draggedPet = nil
        lastDragLocation = nil
        dragOffset = .zero
        
        // 【关键修复 1】
        // 必须在调用 pet.endDrag 之前获取朝向！
        // 因为 pet.endDrag 会改变状态，可能导致 xScale 发生变化（比如重置）
        // 此时 pet 还在 beingDragged 状态，朝向是绝对正确的
        let currentSign = pet.xScale > 0 ? 1.0 : -1.0
        
        // 1. 通知宠物落地/飞出
        pet.endDrag(velocity: velocity)
        
        // 2. 恢复缩放
        // 使用刚才保存的 currentSign，而不是现在去读 pet.xScale
        let restoreScale = SKAction.scaleX(to: 1.0 * currentSign, y: 1.0, duration: 0.1)
        
        pet.run(restoreScale)
    }
    
    // MARK: - Debug / 外部控制接口
    
    // 触发所有宠物的报时
    func triggerHourlyChime() {
        print("🔔 触发整点报时")
        for pet in pets {
            // 使用 trySwitchState，因为 priority = 100，所以除了被拖拽外都会被打断
            pet.trySwitchState(to: .interrupt(.hourlyChime))
        }
    }
    
    /// 测试：触发起风了
    func triggerWindyWeather() {
        pets.forEach { $0.triggerWind() }
    }
    
    /// 测试：改变指定宠物的状态
    func debugChangeState(to state: PetState) {
        pets.first?.trySwitchState(to: state, force: true)
    }
}

// MARK: - 辅助扩展

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
