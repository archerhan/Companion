import SpriteKit

class PetSpriteNode: SKSpriteNode {
    // MARK: - 属性
    let configuration: PetConfiguration
    var petType: PetType { configuration.petType }
    
    // 状态核心
    private(set) var currentState: PetState = .daily(.idle)
    private var previousState: PetState = .daily(.idle) // 用于恢复状态
    
    // 物理/运动参数
    var petHorizontalSpeed: CGFloat = 30.0
    var petVelocity: CGPoint = .zero
    private var timeUntilNextRandomAction: TimeInterval = 5.0
    
    // 交互记录
    private var lastMouseDownTime: TimeInterval = 0
    private var mouseDownCount: Int = 0
    
    // 动画缓存
    private var animations: [PetAnimation: [SKTexture]] = [:]
    private var currentAnimationType: PetAnimation?
    
    // MARK: - 初始化
    init(configuration: PetConfiguration) {
        self.configuration = configuration
        let initialTextureName = "\(configuration.baseName)_front-0"
        let texture = SKTexture(imageNamed: initialTextureName)
        super.init(texture: texture, color: .clear, size: texture.size())
        
        setupPet()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupPet() {
        loadAnimations()
        self.name = "desktopPet_\(configuration.petType.rawValue)"
        self.size = configuration.defaultSize
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        petHorizontalSpeed = CGFloat.random(in: configuration.walkSpeedRange)
        
        // 初始状态
        trySwitchState(to: .daily(.idle), force: true)
    }
    
    // MARK: - 核心：状态切换逻辑 (State Machine Logic)
    
    /// 尝试切换状态
    /// - Returns: 是否切换成功
    @discardableResult
    func trySwitchState(to newState: PetState, force: Bool = false) -> Bool {
        // 1. 相同状态不处理
        if currentState == newState { return true }
        
        // 2. 优先级检查 (Guard)
        // 如果不是强制切换，且新状态优先级 < 当前状态优先级，则拒绝
        if !force && newState.priority < currentState.priority {
            // 例：正在 .system(.focusMode)(50) 时，随机想要 .daily(.walk)(0)，拒绝
            return false
        }
        
        // 3. 执行切换
        previousState = currentState
        currentState = newState
        
        // 4. 应用视觉与逻辑
        handleStateEnter(newState)
        
        return true
    }
    
    private func handleStateEnter(_ state: PetState) {
        // 播放对应动画
        playAnimation(state.animation, loop: state.isLooping)
        
        // 根据状态重置一些物理参数
        switch state {
        case .environment(.falling):
            // 抛出力度初始值，保留水平速度，给一个向下的初速度
            break
        case .environment(.blownByWind):
            // 开启物理模拟(或者模拟物理)
            petVelocity = CGPoint(x: 50, y: 30) // 假设风向
        case .daily(.walking):
            // 确保有速度
            if petHorizontalSpeed == 0 { petHorizontalSpeed = 30 }
        default:
            break
        }
        
        // 重置计时器
        if case .daily = state {
            timeUntilNextRandomAction = TimeInterval.random(in: 5...10)
        }
    }
    
    // MARK: - Update Loop (每帧调用)
    
    func update(deltaTime: TimeInterval) {
        // 1. 物理更新 (Movement)
        updatePhysics(deltaTime: deltaTime)
        
        // 2. 逻辑更新 (AI Decision)
        updateAI(deltaTime: deltaTime)
    }
    
    // 分离出的物理层：只管位置，不管状态怎么变
    private func updatePhysics(deltaTime: TimeInterval) {
        switch currentState {
            
        case .daily(.walking):
            // 左右行走逻辑
            updateWalking(deltaTime: deltaTime)
            
        case .environment(.falling):
            // 下落重力逻辑
            updateGravity(deltaTime: deltaTime)
            
        case .environment(.blownByWind):
            // 风吹逻辑：持续施加力 + 弹性碰撞
            updateWindPhysics(deltaTime: deltaTime)
            
        case .environment(.beingDragged):
            // 拖拽中位置由 Mouse 事件控制，这里不做处理
            break
            
        default:
            // 静态状态，不动
            break
        }
    }
    
    // 分离出的 AI 层：只管思考，决定下一步做什么
    private func updateAI(deltaTime: TimeInterval) {
        // 只有日常状态下，宠物才会自己胡思乱想
        // 如果是 System(高CPU) 或 Environment(被风吹)，AI 暂停
        guard currentState.priority == 0 else { return }
        
        timeUntilNextRandomAction -= deltaTime
        if timeUntilNextRandomAction <= 0 {
            pickRandomDailyState()
        }
    }
    
    // MARK: - 物理实现细节
    
    private func updateWalking(deltaTime: TimeInterval) {
        let parentWidth = parent?.frame.width ?? 800
        let halfWidth = size.width / 2
        
        // 移动
        position.x += petHorizontalSpeed * CGFloat(deltaTime)
        
        // 碰壁反弹
        if (position.x - halfWidth <= 0 && petHorizontalSpeed < 0) ||
           (position.x + halfWidth >= parentWidth && petHorizontalSpeed > 0) {
            petHorizontalSpeed *= -1
            updateDirection()
        }
    }
    
    private func updateGravity(deltaTime: TimeInterval) {
        let gravity: CGFloat = -1500 // 像素/秒平方
        petVelocity.y += gravity * CGFloat(deltaTime)
        
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        // 地面碰撞
        let groundY: CGFloat = 0 + size.height/2
        if position.y <= groundY {
            position.y = groundY
            petVelocity = .zero
            // 落地后回到 Idle
            trySwitchState(to: .daily(.idle), force: true)
        }
        
        // 墙壁反弹
        handleWallBounce()
    }
    
    private func updateWindPhysics(deltaTime: TimeInterval) {
        let windForce = CGPoint(x: 100, y: 20) // 风向
        let gravity: CGFloat = -500
        
        petVelocity.x += windForce.x * CGFloat(deltaTime)
        petVelocity.y += (windForce.y + gravity) * CGFloat(deltaTime)
        
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        // 模拟更混乱的碰撞
        if handleWallBounce() {
            // 如果撞墙了，有概率挂在墙上
            if Bool.random() {
                trySwitchState(to: .environment(.stuckOnEdge), force: true)
            }
        }
        
        // 地面碰撞
        if position.y <= size.height/2 {
            position.y = size.height/2
            petVelocity.y = abs(petVelocity.y) * 0.5 // 弹性地面
        }
    }
    
    @discardableResult
    private func handleWallBounce() -> Bool {
        let parentWidth = parent?.frame.width ?? 800
        let halfWidth = size.width / 2
        var bounced = false
        
        if position.x - halfWidth <= 0 && petVelocity.x < 0 {
            position.x = halfWidth
            petVelocity.x *= -0.6 // 能量损耗
            bounced = true
        } else if position.x + halfWidth >= parentWidth && petVelocity.x > 0 {
            position.x = parentWidth - halfWidth
            petVelocity.x *= -0.6
            bounced = true
        }
        
        if bounced { updateDirection() }
        return bounced
    }
    
    private func updateDirection() {
        // 根据速度方向调整贴图朝向
        let speed = (currentState == .daily(.walking)) ? petHorizontalSpeed : petVelocity.x
        if speed != 0 {
            xScale = (speed > 0) ? abs(xScale) : -abs(xScale)
        }
    }

    // MARK: - 辅助逻辑
    
    private func pickRandomDailyState() {
            // 修正：使用 configuration.capableRandomStates
            // 这里面已经配置好了允许随机触发的状态（如 idle, walking, sitting 等）
            // 不需要再手动 compactMap 转换类型
            
            let allowedStates = configuration.capableRandomStates
            
            // 随机取出一个状态
            guard let randomState = allowedStates.randomElement() else { return }
            
            // 尝试切换 (trySwitchState 内部会自动处理优先级判断)
            trySwitchState(to: randomState)
    }
    
    // MARK: - 动画系统
    
    private func loadAnimations() {
        let petAtlas = SKTextureAtlas(named: configuration.textureAtlasName)
        let animationTypes = PetAnimation.allCases
        
        for type in animationTypes {
            let prefix = "\(configuration.baseName)_\(type.rawValue)-"
            let textureNames = petAtlas.textureNames.filter { $0.hasPrefix(prefix) }.sorted()
            let frames = textureNames.map { petAtlas.textureNamed($0) }
            if !frames.isEmpty {
                animations[type] = frames
            }
        }
    }
    
    func playAnimation(_ type: PetAnimation, loop: Bool = true) {
        guard currentAnimationType != type else { return }
        guard let frames = animations[type], !frames.isEmpty else { return }
        
        // 移除旧动画（如果有 Key，其实 removeAction(forKey:) 更精准，但 removeAllActions 也行）
        removeAllActions()
        currentAnimationType = type
        
        let animateAction = SKAction.animate(with: frames, timePerFrame: 0.12)
        
        if loop {
            // 1. 如果是循环播放：
            // 不需要回调（因为永远不会结束），直接播放并设置 Key
            let repeatAction = SKAction.repeatForever(animateAction)
            run(repeatAction, withKey: "anim")
        } else {
            // 2. 如果是单次播放：
            // 使用 Sequence 包装：[动画 -> 回调 Block]
            let completionBlock = SKAction.run { [weak self] in
                self?.animationDidFinish()
            }
            
            let sequence = SKAction.sequence([animateAction, completionBlock])
            
            // 这样既能设置 Key (方便中途打断)，又能触发回调
            run(sequence, withKey: "anim")
        }
    }
    
    private func animationDidFinish() {
        // 动画结束后的回调。
        // 如果是喝水(Interrupt)，喝完后应该回到之前的状态，或者 Default Idle
        // 这里做一个简单处理：降级回 Daily
        if currentState.priority >= 100 {
             // 强制切回 Idle，后续让 AI 接管
            trySwitchState(to: .daily(.idle), force: true)
        }
    }
    
    // MARK: - 交互入口
    
    // 供 PetScene 调用
    func startDrag() {
        trySwitchState(to: .environment(.beingDragged), force: true)
    }
    
    func endDrag(velocity: CGPoint) {
        self.petVelocity = velocity
        trySwitchState(to: .environment(.falling), force: true)
    }
    
    // 供外部系统监控调用
    func triggerSystemEvent(_ event: PetState.SystemState) {
        trySwitchState(to: .system(event))
    }
    
    func triggerWind() {
        trySwitchState(to: .environment(.blownByWind), force: true)
    }
}

extension PetSpriteNode {
    func triggerSystemEvent(_ type: PetState.InterruptState) {
       trySwitchState(to: .interrupt(type))
    }
}
