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
    
    private let bubbleNode = BubbleNode()
    
    // MARK: - 风吹系统参数
    // 用于风吹的随机扰动计时
    private var windTurbulenceTimer: TimeInterval = 0
    
    private var flightTime: TimeInterval = 0 // 飞行时间累加器
    
    // 随机种子参数，保证每只猫、每次起飞的轨迹都不一样
    private var windPhaseOffset: Double = 0      // 波的相位偏移
    private var windFrequencySlow: Double = 0    // 慢波频率 (大弯)
    private var windFrequencyFast: Double = 0    // 快波频率 (小抖动)
    private var windAmplitude: CGFloat = 0       // 波的幅度 (弯拐多大)
    private var verticalLiftSpeed: CGFloat = 0   // 上升速度
    
    
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
        
        addChild(bubbleNode)
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
            // 如果是从挂住状态变成下落，给个微小的反弹速度
            if previousState == .environment(.stuckOnEdge) {
                petVelocity = CGPoint(x: 0, y: 0) // 直接垂直下落
            }
            break
        case .environment(.blownByWind):
            // 1. 重置飞行计时器
            flightTime = 0
            
            // 2. 随机生成“风的性格”
            // 相位偏移：决定它一开始是先往左还是先往右
            windPhaseOffset = Double.random(in: 0...(2 * .pi))
            
            // 频率：决定拐弯有多急
            windFrequencySlow = Double.random(in: 1.0...2.0) // 1-2秒拐一个大弯
            windFrequencyFast = Double.random(in: 3.0...5.0) // 细节抖动
            
            // 幅度：决定弯拐得有多宽 (像素速度)
            windAmplitude = CGFloat.random(in: 300...500)
            
            // 上升速度：基础上升力
            verticalLiftSpeed = CGFloat.random(in: 50...100)
            
            // 初始给一个向上的速度，防止刚开始掉下来
            petVelocity = CGPoint(x: 0, y: verticalLiftSpeed)
            
            // 开启物理重力影响设为 false (因为我们要完全手动接管轨迹)
            self.physicsBody?.affectedByGravity = false
        case .environment(.stuckOnEdge):
            // 挂住时速度清零
            petVelocity = .zero
        case .daily(.walking):
            // 确保有速度
            if petHorizontalSpeed == 0 { petHorizontalSpeed = 30 }
        default:
            break
        }
        
        if case .interrupt(.hourlyChime) = state {
            showTimeBubble()
        } else {
            // 如果切到了其他状态（比如走路），隐藏气泡
            bubbleNode.hide()
        }
        
        // 重置计时器
        let range = configuration.durationRange(for: state)
        let duration = TimeInterval.random(in: range)
        
        // 更新随机计时器（给低优先级状态用的）
        timeUntilNextRandomAction = duration
        
        // 如果是高优先级状态（报时、提醒），AI 不会接管，必须手动安排退出
        if state.priority >= 100 {
            let wait = SKAction.wait(forDuration: duration)
            let exit = SKAction.run { [weak self] in
                // 时间到，强制切回 Idle
                self?.trySwitchState(to: .daily(.idle), force: true)
            }
            // 给这个动作加个 Key，防止状态提前改变时重复触发
            run(SKAction.sequence([wait, exit]), withKey: "AutoExitState")
        } else {
            // 如果切到了普通状态，移除之前的自动退出倒计时（防止逻辑冲突）
            removeAction(forKey: "AutoExitState")
        }
        
#if DEBUG
        print("状态: \(state) | 持续: \(String(format: "%.1f", duration))s")
#endif
    }
    
    // MARK: - 报时具体实现
    
    private func showTimeBubble() {
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // 根据时间显示不同文案
        let text: String
        if hour == 0 {
            text = "午夜啦！睡觉觉！💤"
        } else if hour < 6 {
            text = "呼呼... \(hour)点..."
        } else if hour == 12 {
            text = "12点！干饭！🍖"
        } else {
            text = "现在是 \(hour) 点整 🕛"
        }
        
        // 显示在头顶 (假设宠物高度 64，气泡在 y=40 处)
        bubbleNode.show(text: text, at: CGPoint(x: 0, y: size.height/2 + 15))
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
        
        case .environment(.stuckOnEdge):
            // 挂在墙上不动，不需要物理计算
            break
            
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
        let gravity: CGFloat = -800 // 像素/秒平方
        petVelocity.y += gravity * CGFloat(deltaTime)
        
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        // 地面碰撞
        let groundY: CGFloat = 0 + size.height/2
        if position.y <= groundY {
            position.y = groundY
            petVelocity = .zero
            // 落地后回到 Idle
            trySwitchState(to: .daily(.walking), force: true)
        }
        
        // 墙壁反弹
        handleWallBounce()
    }
    
    private func updateWindPhysics(deltaTime: TimeInterval) {
        guard let parent = parent else { return }
        
        // 1. 累加时间
        flightTime += deltaTime
        
        // 2. 计算 X 轴的复合正弦波速度 (S型曲线的核心)
        // 第一层波：大摆动 (决定整体走势)
        let slowWave = sin(flightTime * windFrequencySlow + windPhaseOffset)
        // 第二层波：小抖动 (增加不规则感)
        let fastWave = sin(flightTime * windFrequencyFast) * 0.3
        
        // 合成 X 轴速度
        // 加上一个微小的随机扰动，防止轨迹完全由于数学公式而显得太死板
        let noise = CGFloat.random(in: -20...20)
        petVelocity.x = (CGFloat(slowWave + fastWave) * windAmplitude) + noise
        
        // 3. 计算 Y 轴速度 (上升 + 浮动)
        // 并不是匀速上升，而是忽快忽慢
        let liftVariation = sin(flightTime * 3.0) * 30 // 上下的起伏感
        petVelocity.y = verticalLiftSpeed + CGFloat(liftVariation)
        
        // 4. 应用位移
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        // 5. 旋转效果 (随风摆动)
        // 身体根据 X 轴速度倾斜，模仿空气动力学
        // 限制最大旋转角度在 -45度 到 45度 之间
        let targetRotation = -petVelocity.x * 0.002
        let maxRotation = CGFloat.pi / 4
        zRotation = targetRotation.clamped(to: -maxRotation...maxRotation)
        
        // 6. 边界与挂墙检测 (保持之前的逻辑)
        checkStuckOnEdge(parentFrame: parent.frame)
    }
    
    // MARK: - 4. 检测挂墙 (Stuck Check)
    
    private func checkStuckOnEdge(parentFrame: CGRect) {
        let halfW = size.width / 2
        let halfH = size.height / 2
        
        // 定义挂住的阈值：屏幕高度的 50% 以上
        // 你可以根据需要调整这个比例，比如 0.3 (70%以上) 或 0.5 (一半以上)
        let stickHeightThreshold = parentFrame.height * 0.5
        
        var isStuck = false
        var stuckPos = position
        
        // --- 1. 左侧检测 ---
        if position.x - halfW <= 0 {
            // 物理限制：不管有没有挂住，都不能飞出屏幕左边
            position.x = halfW
            
            // 只有高度足够，才判定为“挂住”
            if position.y > stickHeightThreshold {
                stuckPos.x = halfW
                isStuck = true
            } else {
                // 如果高度不够，只是碰壁。
                // 此时可以让它向右反弹一下，防止一直蹭墙
                // 也可以什么都不做，让正弦波风力自己把它带离
                if petVelocity.x < 0 {
                    petVelocity.x = abs(petVelocity.x) * 0.5 // 简单的反弹
                }
            }
        }
        
        // --- 2. 右侧检测 ---
        else if position.x + halfW >= parentFrame.width {
            // 物理限制
            position.x = parentFrame.width - halfW
            
            // 高度判断
            if position.y > stickHeightThreshold {
                stuckPos.x = parentFrame.width - halfW
                isStuck = true
            } else {
                // 低空碰壁反弹
                if petVelocity.x > 0 {
                    petVelocity.x = -abs(petVelocity.x) * 0.5
                }
            }
        }
        
        // --- 3. 顶部检测 (天花板) ---
        // 碰到顶肯定挂住，不管左右
        else if position.y + halfH >= parentFrame.height {
            stuckPos.y = parentFrame.height - halfH
            isStuck = true
        }
        
        // --- 4. 状态切换执行 ---
        if isStuck {
            // 修正最终吸附位置
            position = stuckPos
            
            // 恢复身体旋转 (挂住时要正过来，或者你可以保持一点倾斜看起来像挂歪了)
            zRotation = 0
            
            // 触发状态切换
            trySwitchState(to: .environment(.stuckOnEdge), force: true)
        }
    }
    
    // MARK: - 5. 解救逻辑 (点击事件)
    
    // 确保你的 handleMouseDown 或 updateWindowInteraction 调用了这个逻辑
    // 建议在 PetSpriteNode 中添加一个处理点击的方法
    
    func tryRescue() -> Bool {
        if case .environment(.stuckOnEdge) = currentState {
            // 点击了解救 -> 切换到下落
            trySwitchState(to: .environment(.falling), force: true)
            return true
        }
        return false
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
        // 如果是被风吹状态，不要频繁翻转，或者只根据大趋势翻转
        if case .environment(.blownByWind) = currentState {
            // 只有当速度很大时才翻转，避免在 0 附近抖动
            if abs(petVelocity.x) > 50 {
                 xScale = (petVelocity.x > 0) ? abs(xScale) : -abs(xScale)
                 // 记得气泡也要反转
                 // bubbleNode.xScale = ...
            }
            return
        }

        // 原有的走路翻转逻辑
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
