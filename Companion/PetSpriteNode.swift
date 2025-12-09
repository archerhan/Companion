// PetSpriteNode.swift
import SpriteKit

enum PetState {
    case walking
    case idle
    case sitting
    case beingDragged
    case eating
    case angry
    case falling
    case sleeping
}

enum PetAnimation: String, CaseIterable {
    case walk
    case idle
    case eat
    case drag
    case sleep
    case angry
    case front
    
    var animationKey: String {
        return "\(self.rawValue)_animation"
    }
}

class PetSpriteNode: SKSpriteNode {
    // MARK: - 属性
    private let configuration: PetConfiguration
    var petType: PetType { configuration.petType }
    
    // 宠物状态相关
    var petState: PetState = .idle {
        didSet {
            handleStateChange(from: oldValue, to: petState)
        }
    }
    
    var timeUntilNextStateChange: TimeInterval = 0
    var timeUntilHungry: TimeInterval = 30.0
    var previousStateBeforeAction: PetState = .walking
    var petHorizontalSpeed: CGFloat = 30.0
    var petVelocity: CGPoint = .zero
    
    // 计时器
    private var lastMouseDownTime: TimeInterval = 0
    private var mouseDownCount: Int = 0
    
    // 动画相关
    private var animations: [PetAnimation: [SKTexture]] = [:]
    private var currentAnimation: PetAnimation?
    
    // MARK: - 初始化器
    init(configuration: PetConfiguration) {
        self.configuration = configuration
        
        // 使用配置中的默认图片作为初始纹理
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
        loadAllAnimations()
        
        self.name = "desktopPet_\(configuration.petType.rawValue)"
        self.size = configuration.defaultSize
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // 初始化速度
        petHorizontalSpeed = CGFloat.random(in: configuration.walkSpeedRange)
        
        // 初始化状态
        playAnimation(.idle)
        resetStateTimer()
        resetHungerTimer()
    }
    
    // MARK: - 动画加载
    private func loadAllAnimations() {
        let petAtlas = SKTextureAtlas(named: configuration.textureAtlasName)
        
        for animationType in configuration.animations {
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
            } else {
                print("Warning: No textures found for animation \(animationType.rawValue) with prefix \(texturePrefix)")
            }
        }
    }
    
    // MARK: - 计时器重置
    private func resetStateTimer() {
        if let durationRange = configuration.stateDurations[petState] {
            timeUntilNextStateChange = TimeInterval.random(in: durationRange)
        } else {
            // 默认值
            timeUntilNextStateChange = TimeInterval.random(in: 3...8)
        }
    }
    
    private func resetHungerTimer() {
        timeUntilHungry = TimeInterval.random(in: 20...30)
    }
    
    // MARK: - 更新循环
    func update(deltaTime: TimeInterval) {
        // --- 处理下落状态 ---
        if petState == .falling {
            handleFallingState(deltaTime: deltaTime)
            return
        }
        
        // --- 更新计时器 ---
        if petState == .walking || petState == .idle || petState == .sitting {
            timeUntilNextStateChange -= deltaTime
            timeUntilHungry -= deltaTime
            
            // 检查是否饿了
            if timeUntilHungry <= 0 {
                previousStateBeforeAction = petState
                petState = .eating
                return
            }
            
            // 检查是否需要切换状态
            if timeUntilNextStateChange <= 0 {
                transitionToNextState()
                resetStateTimer()
            }
        }
        
        // 行走状态更新位置
        if petState == .walking {
            updateWalkingPosition(deltaTime: deltaTime)
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
            petState = previousStateBeforeAction
            petVelocity = .zero
        }
        
        position = newPosition
        
        // 更新方向
        if petVelocity.x != 0 {
            let shouldFaceRight = petVelocity.x > 0
            xScale = abs(xScale) * (shouldFaceRight ? 1.0 : -1.0)
        }
    }
    
    private func transitionToNextState() {
        switch petState {
        case .walking:
            petState = .idle
        case .idle:
            petState = .sitting
        case .sitting:
            petState = .walking
        default:
            petState = .idle
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
        if petHorizontalSpeed > 0 {
            xScale = abs(xScale)
        } else {
            xScale = -abs(xScale)
        }
    }
    
    // MARK: - 状态处理
    private func handleStateChange(from oldState: PetState, to newState: PetState) {
        guard oldState != newState else { return }
        
        switch newState {
        case .walking:
            playAnimation(.walk)
            
        case .idle:
            playAnimation(.idle)
            
        case .sitting:
            if configuration.animations.contains(.front) {
                playAnimation(.front)
            } else {
                playAnimation(.idle) // 备用
            }
            
        case .beingDragged, .falling:
            if configuration.animations.contains(.drag) {
                playAnimation(.drag)
            } else {
                playAnimation(.idle) // 备用
            }
        
        case .sleeping:
            if configuration.animations.contains(.sleep) {
                playAnimation(.sleep)
            } else {
                playAnimation(.idle) // 备用
            }
            
            let breatheIn = SKAction.fadeAlpha(to: 0.7, duration: 1.5)
            let breatheOut = SKAction.fadeAlpha(to: 0.8, duration: 1.5)
            let breathing = SKAction.repeatForever(SKAction.sequence([breatheIn, breatheOut]))
            run(breathing, withKey: "breathing")
            
            let sleepDuration = TimeInterval.random(in: 30...60)
            
            run(SKAction.wait(forDuration: sleepDuration)) { [weak self] in
                guard let self = self else { return }
                if self.petState == .sleeping {
                    self.removeAction(forKey: "breathing")
                    self.handleAfterSleepingTransition()
                }
            }
                
        case .eating:
            if configuration.animations.contains(.eat) {
                let repeatCount = 10
                playAnimation(.eat, repeatsForever: false, repeatCount: repeatCount)
                
                let singleDuration = getAnimationDuration(for: .eat)
                let totalDuration = singleDuration * TimeInterval(repeatCount)
                
                run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
                    guard let self = self else { return }
                    self.previousStateBeforeAction = self.petState
                    self.petState = .sleeping
                    self.resetHungerTimer()
                }
            } else {
                // 如果没有吃动画，直接进入睡眠状态
                petState = .sleeping
            }
                
        case .angry:
            if configuration.animations.contains(.angry) {
                let repeatCount = 2
                playAnimation(.angry, repeatsForever: false, repeatCount: repeatCount)
                
                let singleDuration = getAnimationDuration(for: .angry)
                let totalDuration = singleDuration * TimeInterval(repeatCount)
                
                run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
                    guard let self = self else { return }
                    if self.petState == .angry {
                        self.petState = self.previousStateBeforeAction
                    }
                }
            } else {
                // 如果没有生气动画，切换回之前状态
                petState = previousStateBeforeAction
            }
        }
    }
    
    private func handleAfterSleepingTransition() {
        let nextStates: [PetState] = [.sitting, .walking, .idle]
        let randomIndex = Int.random(in: 0..<nextStates.count)
        let nextState = nextStates[randomIndex]
        
        petState = nextState
        resetStateTimer()
    }
    
    // MARK: - 动画控制
    func playAnimation(_ type: PetAnimation, repeatsForever: Bool = true, timePerFrame: TimeInterval = 0.1, repeatCount: Int = 1) {
        guard currentAnimation != type else { return }
        guard let frames = animations[type], !frames.isEmpty else {
            print("No frames available for animation: \(type.rawValue)")
            return
        }
        
        if let current = currentAnimation {
            self.removeAction(forKey: current.animationKey)
        }
        
        let animationAction = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        
        if repeatsForever {
            let repeatAction = SKAction.repeatForever(animationAction)
            self.run(repeatAction, withKey: type.animationKey)
        } else {
            if repeatCount > 1 {
                let repeatAction = SKAction.repeat(animationAction, count: repeatCount)
                self.run(repeatAction, withKey: type.animationKey)
            } else {
                self.run(animationAction, withKey: type.animationKey)
            }
        }
        
        self.currentAnimation = type
    }
    
    func getAnimationDuration(for type: PetAnimation, timePerFrame: TimeInterval = 0.1) -> TimeInterval {
        guard let frames = animations[type] else {
            return 2.0
        }
        return TimeInterval(frames.count) * timePerFrame
    }
    
    // MARK: - 交互处理
    func handleMouseDown(at location: CGPoint, event: NSEvent) -> Bool {
        guard self.contains(location) else { return false }
        
        // 特殊状态不能交互
        let nonInteractiveStates: [PetState] = [.falling, .sleeping, .eating, .angry]
        if nonInteractiveStates.contains(petState) {
            return true // 点击到了，但不能交互
        }
        
        // 快速点击检测
        let currentTime = event.timestamp
        if currentTime - lastMouseDownTime < 0.3 {
            mouseDownCount += 1
        } else {
            mouseDownCount = 1
        }
        lastMouseDownTime = currentTime
        
        // 如果达到生气阈值
        let dailyStates: [PetState] = [.walking, .idle, .sitting]
        if mouseDownCount >= 3 && dailyStates.contains(petState) {
            mouseDownCount = 0
            previousStateBeforeAction = petState
            petState = .angry
            return true
        }
        
        // 开始拖拽
        if dailyStates.contains(petState) {
            previousStateBeforeAction = petState
            petState = .beingDragged
            return true
        }
        
        return true
    }
}

