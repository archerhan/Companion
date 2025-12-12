// PetSpriteNode.swift - 修正版本
import SpriteKit

class PetSpriteNode: SKSpriteNode {
    // MARK: - 属性
    private let configuration: PetConfiguration
    var petType: PetType { configuration.petType }
    
    // 状态相关 - 使用嵌套枚举
    var currentState: PetState = .daily(.idle) {
        didSet {
            handleStateChange(from: oldValue, to: currentState)
        }
    }
    
    var previousState: PetState = .daily(.walking)
    var timeUntilNextStateChange: TimeInterval = 0
    var timeUntilHungry: TimeInterval = 30.0
    var petHorizontalSpeed: CGFloat = 30.0
    var petVelocity: CGPoint = .zero
    
    // 交互相关
    private var lastMouseDownTime: TimeInterval = 0
    private var mouseDownCount: Int = 0
    
    // 动画相关
    private var animations: [PetAnimation: [SKTexture]] = [:]
    private var currentAnimation: PetAnimation?
    
    // MARK: - 初始化器
    init(configuration: PetConfiguration) {
        self.configuration = configuration
        
        let initialTextureName = "\(configuration.baseName)_front-0"
        let texture = SKTexture(imageNamed: initialTextureName)
        
        super.init(texture: texture, color: .clear, size: texture.size())
        
        setupPet()
    }
    
    convenience init(petType: PetType) {
        let config = PetType.configuration(for: petType)
        self.init(configuration: config)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 设置方法
    private func setupPet() {
        loadAnimations()
        
        self.name = "desktopPet_\(configuration.petType.rawValue)"
        self.size = configuration.defaultSize
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        petHorizontalSpeed = CGFloat.random(in: configuration.walkSpeedRange)
        
        playAnimation(.front)
        resetStateTimer()
        resetHungerTimer()
        #if DEBUG
        debugPetConfigurations()
        #endif
    }
    
    private func debugPetConfigurations() {
        print("""
            --- 宠物配置信息 ---
            当前宠物:\(configuration.petType.rawValue)
            动画集:\(configuration.textureAtlasName)
            大小:\(size)
            行走速度:\(petHorizontalSpeed)
            """)
        print("动作:")
        for state in configuration.availableStates {
            print("\(state)")
        }
        print("动画:")
        for animation in animations {
            print("\(animation.key)共有:\(animation.value.count)帧")
        }
        print("--- END ---")
    }
    
    // MARK: - 动画加载
    private func loadAnimations() {
        let petAtlas = SKTextureAtlas(named: configuration.textureAtlasName)
        
        // 加载所有可用的动画类型
        let animationTypes = Set(configuration.availableStates.map { $0.animation })
        
        for animationType in animationTypes {
            var frames: [SKTexture] = []
            let texturePrefix = "\(configuration.baseName)_\(animationType.rawValue)-"
            
            let textureNames = petAtlas.textureNames.filter {
                $0.starts(with: texturePrefix)
            }.sorted()
            
            for textureName in textureNames {
                frames.append(petAtlas.textureNamed(textureName))
            }
            
            if !frames.isEmpty {
                animations[animationType] = frames
            }
        }
    }
    
    // MARK: - 计时器重置
    private func resetStateTimer() {
        let durationRange = configuration.stateDuration(for: currentState)
        timeUntilNextStateChange = TimeInterval.random(in: durationRange)
    }
    
    private func resetHungerTimer() {
        timeUntilHungry = TimeInterval.random(in: 20...30)
    }
    
    // MARK: - 更新循环
    func update(deltaTime: TimeInterval) {
        // 处理不可交互状态
        if case .nonInteractive(let state) = currentState {
            handleNonInteractiveState(state, deltaTime: deltaTime)
            return
        }
        
        // 更新日常状态
        if currentState.canAutoTransition {
            timeUntilNextStateChange -= deltaTime
            timeUntilHungry -= deltaTime
            
            // 检查饥饿
            if timeUntilHungry <= 0, let eatingState = getEatingState() {
                previousState = currentState
                currentState = eatingState
                return
            }
            
            // 检查状态切换
            if timeUntilNextStateChange <= 0 {
                transitionToNextDailyState()
            }
        }
        
        // 行走状态更新位置
        if case .daily(.walking) = currentState {
            updateWalkingPosition(deltaTime: deltaTime)
        }
    }
    
    private func handleNonInteractiveState(_ state: PetState.NonInteractiveState, deltaTime: TimeInterval) {
        switch state {
        case .falling:
            handleFallingState(deltaTime: deltaTime)
        case .beingDragged:
            // 拖拽位置由外部控制
            break
        }
    }
    
    private func handleFallingState(deltaTime: TimeInterval) {
        let gravity = CGVector(dx: 0, dy: -100)
        petVelocity.y += CGFloat(gravity.dy) * CGFloat(deltaTime)
        petVelocity.x = petHorizontalSpeed * 0.8
        
        var newPosition = position
        newPosition.x += petVelocity.x * CGFloat(deltaTime)
        newPosition.y += petVelocity.y * CGFloat(deltaTime)
        
        let petHalfWidth = size.width / 2
        let petHalfHeight = size.height / 2
        
        // 边界检查
        if newPosition.x - petHalfWidth <= 0 && petVelocity.x < 0 {
            newPosition.x = petHalfWidth
            petVelocity.x *= -0.5
            petHorizontalSpeed *= -0.5
        } else if newPosition.x + petHalfWidth >= parent?.frame.width ?? 800 && petVelocity.x > 0 {
            newPosition.x = (parent?.frame.width ?? 800) - petHalfWidth
            petVelocity.x *= -0.5
            petHorizontalSpeed *= -0.5
        }
        
        // 地面碰撞
        let groundY: CGFloat = 0
        if newPosition.y - petHalfHeight <= groundY && petVelocity.y < 0 {
            newPosition.y = groundY + petHalfHeight
            petVelocity = .zero
            transitionToNextDailyState()
        }
        
        position = newPosition
        
        // 更新方向
        if petVelocity.x != 0 {
            xScale = abs(xScale) * (petVelocity.x > 0 ? 1.0 : -1.0)
        }
    }
    
    private func updateWalkingPosition(deltaTime: TimeInterval) {
        let petHalfWidth = size.width / 2
        if (position.x - petHalfWidth <= 0 && petHorizontalSpeed < 0) ||
           (position.x + petHalfWidth >= parent?.frame.width ?? 800 && petHorizontalSpeed > 0) {
            petHorizontalSpeed *= -1
            updateDirection()
        }
        position.x += petHorizontalSpeed * CGFloat(deltaTime)
    }
    
    private func updateDirection() {
        xScale = petHorizontalSpeed > 0 ? abs(xScale) : -abs(xScale)
    }
    
    // MARK: - 状态处理
    private func handleStateChange(from oldState: PetState, to newState: PetState) {
        // 这里不再需要guard，因为我们已经实现了Equatable
        if oldState == newState { return }
        
        // 停止所有动画
        removeAllActions()
        
        // 播放新动画
        playAnimation(newState.animation)
        
        // 特殊状态处理
        switch newState {
        case .daily(.sleeping):
            scheduleWakeUp()
            
        case .interrupt(.eating):
            scheduleFinishEating()
            
        case .play(.sliding):
            scheduleFinishPlayState()
            
        case .nonInteractive(.beingDragged):
            // 开始拖拽
            break
            
        case .nonInteractive(.falling):
            petVelocity = CGPoint(x: petHorizontalSpeed * 0.8, y: 50)
            
        default:
            resetStateTimer()
        }
    }
    
    private func transitionToNextDailyState() {
        let dailyStates = configuration.states(in: .daily)
        guard !dailyStates.isEmpty else { return }
        
        // 过滤掉当前状态（如果当前是daily状态）
        let availableStates = dailyStates.filter { $0 != currentState }
        guard !availableStates.isEmpty else { return }
        
        let randomIndex = Int.random(in: 0..<availableStates.count)
        currentState = availableStates[randomIndex]
    }
    
    private func getEatingState() -> PetState? {
        return configuration.states(in: .interrupt).first
    }
    
    // MARK: - 特殊状态处理
    private func scheduleWakeUp() {
        let sleepDuration = TimeInterval.random(in: configuration.stateDuration(for: .daily(.sleeping)))
        run(SKAction.wait(forDuration: sleepDuration)) { [weak self] in
            guard let self = self else { return }
            if case .daily(.sleeping) = self.currentState {
                self.resetHungerTimer()
                self.transitionToNextDailyState()
            }
        }
    }
    
    private func scheduleFinishEating() {
        let repeatCount = 5
        let singleDuration = getAnimationDuration(for: .eat)
        let totalDuration = singleDuration * TimeInterval(repeatCount)
        
        run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
            guard let self = self else { return }
            if case .interrupt = self.currentState {
                self.resetHungerTimer()
                self.currentState = .daily(.sleeping)
            }
        }
    }
    
    private func scheduleFinishPlayState() {
        let repeatCount = 2
        let singleDuration = getAnimationDuration(for: currentState.animation)
        let totalDuration = singleDuration * TimeInterval(repeatCount)
        
        run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
            guard let self = self else { return }
            if case .play = self.currentState {
                self.currentState = .daily(.idle)
            }
        }
    }
    
    // MARK: - 动画控制
    func playAnimation(_ type: PetAnimation, repeatsForever: Bool = true, timePerFrame: TimeInterval = 0.1, repeatCount: Int = 1) {
        guard currentAnimation != type else { return }
        guard let frames = animations[type], !frames.isEmpty else { return }
        
        if let current = currentAnimation {
            removeAction(forKey: current.animationKey)
        }
        
        let animationAction = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        
        if repeatsForever {
            run(SKAction.repeatForever(animationAction), withKey: type.animationKey)
        } else {
            if repeatCount > 1 {
                let repeatAction = SKAction.repeat(animationAction, count: repeatCount)
                run(repeatAction, withKey: type.animationKey)
            } else {
                run(animationAction, withKey: type.animationKey)
            }
        }
        
        currentAnimation = type
    }
    
    func getAnimationDuration(for type: PetAnimation, timePerFrame: TimeInterval = 0.1) -> TimeInterval {
        guard let frames = animations[type] else { return 2.0 }
        return TimeInterval(frames.count) * timePerFrame
    }
    
    // MARK: - 交互处理
    func handleMouseDown(at location: CGPoint, event: NSEvent) -> Bool {
        guard self.contains(location) else { return false }
        
        // 检查是否可以交互
        guard currentState.canInteract else { return true }
        
        // 快速点击检测
        let currentTime = event.timestamp
        if currentTime - lastMouseDownTime < 0.3 {
            mouseDownCount += 1
        } else {
            mouseDownCount = 1
        }
        lastMouseDownTime = currentTime
        
        // 快速点击触发玩耍状态
        if mouseDownCount >= 3 {
            handleTripleClick()
            return true
        }
        
        // 拖拽
        handleDragStart()
        return true
    }
    
    private func handleTripleClick() {
        mouseDownCount = 0
        
        let playStates = configuration.states(in: .play)
        guard !playStates.isEmpty else { return }
        
        previousState = currentState
        
        // 随机选择一个玩耍状态
        let randomIndex = Int.random(in: 0..<playStates.count)
        currentState = playStates[randomIndex]
    }
    
    private func handleDragStart() {
        previousState = currentState
        
        // 尝试进入拖拽状态
        if let dragState = configuration.states(in: .nonInteractive)
            .first(where: {
                if case .nonInteractive(.beingDragged) = $0 {
                    return true
                } else {
                    return false
                }
            }) {
            currentState = dragState
        } else {
            // 如果没有拖拽状态，则进入下落状态
            if let fallingState = configuration.states(in: .nonInteractive)
                .first(where: {
                    if case .nonInteractive(.falling) = $0 {
                        return true
                    } else {
                        return false
                    }
                }) {
                currentState = fallingState
            }
        }
    }
    
    func handleMouseUp() {
        if case .nonInteractive(.beingDragged) = currentState {
            if let fallingState = configuration.states(in: .nonInteractive)
                .first(where: {
                    if case .nonInteractive(.falling) = $0 {
                        return true
                    } else {
                        return false
                    }
                }) {
                currentState = fallingState
            }
        }
    }
    
    func updateDragPosition(to position: CGPoint) {
        if case .nonInteractive(.beingDragged) = currentState {
            self.position = position
        }
    }
}
