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
    
    // 添加一个变量暂存拖拽时的方向
    private var dragDirection: CGFloat = 0
    // 记录拖拽时的方向 (默认向右 1.0)
    private var currentDragDirection: CGFloat = 1.0
    
    
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
            // 1. 播放对应动画
            playAnimation(state.animation, loop: state.isLooping)
            
            // 2. 根据状态重置一些物理参数 (这部分保留你写的逻辑)
            switch state {
            case .environment(.falling):
                zRotation = .zero
                if previousState == .environment(.stuckOnEdge) {
                    petVelocity = CGPoint(x: 0, y: 0)
                }
                
            case .environment(.blownByWind):
                flightTime = 0
                windPhaseOffset = Double.random(in: 0...(2 * .pi))
                windFrequencySlow = Double.random(in: 1.0...2.0)
                windFrequencyFast = Double.random(in: 3.0...5.0)
                windAmplitude = CGFloat.random(in: 300...500)
                verticalLiftSpeed = CGFloat.random(in: 50...100)
                petVelocity = CGPoint(x: 0, y: verticalLiftSpeed)
                self.physicsBody?.affectedByGravity = false
                
            case .environment(.stuckOnEdge):
                petVelocity = .zero
                
            case .daily(.walking):
                if petHorizontalSpeed == 0 {
                    let randomDir: CGFloat = Bool.random() ? 1.0 : -1.0
                    petHorizontalSpeed = 30 * randomDir
                }
                updateDirection()
                
            default:
                break
            }
            
            // 3. 气泡逻辑
            if case .interrupt(.hourlyChime) = state {
                showTimeBubble()
            } else if case .interrupt(.waterReminder) = state {
                showWaterBubble()
            } else {
                bubbleNode.hide()
            }
            
            // 4. 获取配置时长 (用于 AI 随机 或 自动退出)
            let range = configuration.durationRange(for: state)
            let duration = TimeInterval.random(in: range)
            
            // 更新 AI 计时器 (这个只对 priority=0 的 Daily 状态生效，其他状态 UpdateAI 会直接 return，所以这里赋值没副作用)
            timeUntilNextRandomAction = duration
            
            // ------------------------------------------------------------------
            // 【核心修复】 显式区分哪些状态需要“时间到了自动退出”，哪些绝对不能自动退出
            // 不要再用 state.priority >= 100 来判断了！
            // ------------------------------------------------------------------
            
            switch state {
                
            case .interrupt:
                // 【必须退出】：喝水、报时
                // 这些是临时状态，播放完配置的 duration (比如10秒) 后必须强制切回 Idle
                let wait = SKAction.wait(forDuration: duration)
                let exit = SKAction.run { [weak self] in
                    self?.trySwitchState(to: .daily(.idle), force: true)
                }
                // 设置 Key 以便状态提前改变时能取消它
                run(SKAction.sequence([wait, exit]), withKey: "AutoExitState")
                
            case .system(let s):
                // 【选择性退出】：系统状态
                // 烦躁/低电量可以设定一段时间后恢复，但专注模式通常不自动恢复
                if s == .highCPU || s == .lowBattery {
                    let wait = SKAction.wait(forDuration: duration)
                    let exit = SKAction.run { [weak self] in
                        self?.trySwitchState(to: .daily(.idle), force: true)
                    }
                    run(SKAction.sequence([wait, exit]), withKey: "AutoExitState")
                } else {
                    removeAction(forKey: "AutoExitState")
                }
                
            case .environment:
                // 【绝对禁止自动退出】：风吹、拖拽、挂墙、下落
                // 这些由物理逻辑（handleStateEnter 顶部的代码 或 updatePhysics）控制结束。
                // 无论配置里的 duration 是多少，都要移除倒计时！
                removeAction(forKey: "AutoExitState")
                
            case .daily, .play:
                // 【不强制退出】：日常
                // 由 updateAI() 轮询来决定下一个动作
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
    
    // MARK: - 提醒喝水具体实现
    private func showWaterBubble() {
        let texts = [
            "该喝水啦！🥤",
            "补充水分时间！💧",
            "咕嘟咕嘟...🚰",
            "健康第一，喝水！🥛"
        ]
        // 随机选一句文案
        let text = texts.randomElement() ?? "喝水啦！"
        // 显示在头顶
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
        // ... 前面的重力代码保持不变 ...
        let gravity: CGFloat = -1500
        petVelocity.y += gravity * CGFloat(deltaTime)
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        // 地面碰撞检测
        let groundY: CGFloat = 0 + size.height/2
        if position.y <= groundY {
            position.y = groundY
            
            // 【新增逻辑】落地瞬间，顺势而为
            // 如果落地时有明显的水平速度，就让宠物继续往那个方向走
            if abs(petVelocity.x) > 10 {
                let landingDir: CGFloat = petVelocity.x > 0 ? 1.0 : -1.0
                petHorizontalSpeed = abs(petHorizontalSpeed) * landingDir
            }
            
            petVelocity = .zero
            // 落地后切换回 Walking
            trySwitchState(to: .daily(.walking), force: true)
        }
        
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
    
    // 提供给外部（PetScene）调用，用于更新拖拽方向
    func updateDragFacing(deltaX: CGFloat) {
        guard deltaX != 0 else { return }
        currentDragDirection = deltaX
        updateDirection()
    }
    
    private func updateDirection() {
        // 1. 确定参考速度/方向
        var targetDirection: CGFloat = 0
        
        // 根据状态决定参考谁
        if case .environment(.beingDragged) = currentState {
            // 【关键】拖拽时，完全听从鼠标的记录，忽略 petVelocity 或 petHorizontalSpeed
            targetDirection = currentDragDirection
        } else if case .daily(.walking) = currentState {
            targetDirection = petHorizontalSpeed
        } else if case .environment(.blownByWind) = currentState {
            targetDirection = petVelocity.x
        } else {
            // 其他状态如果有速度也参考一下
            if abs(petVelocity.x) > 0.1 { targetDirection = petVelocity.x }
        }
        
        // 2. 如果方向不明确（静止），直接返回，保持上一次的朝向
        guard abs(targetDirection) > 0.1 else { return }
        
        // 3. 计算翻转逻辑
        // true = 目标向右，false = 目标向左
        let shouldFaceRight = targetDirection > 0
        
        // 获取配置：你的素材原本是朝右的吗？
        // 如果你的图原本朝右(true)，想让它朝左，就需要翻转(-1)
        let isAssetFacingRight = configuration.isTextureFacingRight
        
        // 计算最终缩放系数
        // 如果 (目标向右) 和 (素材向右) 一致 -> 1.0 (正常)
        // 如果 (目标向右) 和 (素材向右) 不一致 -> -1.0 (翻转)
        let multiplier: CGFloat = (shouldFaceRight == isAssetFacingRight) ? 1.0 : -1.0
        
        // 4. 应用缩放
        let newXScale = abs(xScale) * multiplier
        if xScale != newXScale {
            xScale = newXScale
            // 修正气泡朝向 (负负得正)
            bubbleNode.xScale = (xScale < 0) ? -1 : 1
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
        currentAnimationType = type
        removeAction(forKey: "anim")
        
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
        
        let targetDirection: CGFloat
        // 如果有明显的抛掷速度（>10），听抛掷的
        if abs(velocity.x) > 10 {
            targetDirection = velocity.x
        } else {
            // 如果只是慢慢放下，听刚才记录的拖拽方向
            // 因为我们上面修复了 updateDragFacing，这里的 currentDragDirection 现在是准确的了
            targetDirection = currentDragDirection
        }
        
        // 更新行走速度方向
        let directionSign: CGFloat = targetDirection > 0 ? 1.0 : -1.0
        petHorizontalSpeed = abs(petHorizontalSpeed) * directionSign
        
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
