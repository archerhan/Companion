import SpriteKit
import Cocoa

// MARK: - 主类定义 & 属性存储
class PetSpriteNode: SKSpriteNode {
    // MARK: - 基础属性
    let configuration: PetConfiguration
    var petType: PetType { configuration.petType }
    
    // MARK: - 状态核心
    private(set) var currentState: PetState = .daily(.idle)
    var previousState: PetState = .daily(.idle) // 改为 internal 以便 Brain 访问
    
    // MARK: - 物理/运动属性
    var petHorizontalSpeed: CGFloat = 30.0
    var petVelocity: CGPoint = .zero
    
    // 风吹系统参数
    var flightTime: TimeInterval = 0
    var windPhaseOffset: Double = 0
    var windFrequencySlow: Double = 0
    var windFrequencyFast: Double = 0
    var windAmplitude: CGFloat = 0
    var verticalLiftSpeed: CGFloat = 0
    
    // 拖拽相关
    var currentDragDirection: CGFloat = 1.0
    
    // MARK: - 逻辑/AI 属性
    var timeUntilNextRandomAction: TimeInterval = 5.0
    var isWalkingToFocusLocation: Bool = false
    var focusTargetLocation: CGPoint?
    var isPomodoroActive: Bool = false // 番茄钟标记
    
    // MARK: - 动画/视觉属性
    // 缓存字典改为 internal
    var animations: [PetAnimation: [SKTexture]] = [:]
    var currentAnimationType: PetAnimation?
    let bubbleNode = BubbleNode()
    
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
        loadAnimations() // 在 +Animation.swift
        self.name = "desktopPet_\(configuration.petType.rawValue)"
        self.size = configuration.defaultSize
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        petHorizontalSpeed = CGFloat.random(in: configuration.walkSpeedRange)
        
        // 初始状态
        trySwitchState(to: .daily(.idle), force: true)
        
        addChild(bubbleNode)
    }
    
    // MARK: - 核心：状态机入口
    @discardableResult
    func trySwitchState(to newState: PetState, force: Bool = false) -> Bool {
        // 1. 相同状态不处理
        if currentState == newState && !force { return true }
        
        // 2. 优先级检查
        if !force && newState.priority < currentState.priority {
            return false
        }
        
        // 3. 特殊逻辑打断 (针对番茄钟寻路)
        // 如果切换到了 Environment (风吹/挂墙)，必须立即打断“去专注的路上”
        if case .environment = newState {
            isWalkingToFocusLocation = false
            focusTargetLocation = nil
            self.physicsBody?.affectedByGravity = false
        }
        
        previousState = currentState
        currentState = newState
        
        // 4. 调用 +Brain.swift 中的逻辑处理
        handleStateEnter(newState)
        
        return true
    }
    
    // MARK: - 主循环
    func update(deltaTime: TimeInterval) {
        // 1. 物理更新
        // 【优化】: 只有在需要动的时候才计算物理
        // 如果是 idle, sitting, sleeping, eating，物理层其实是完全静止的
        // 可以直接跳过 updatePhysics 的 switch 判断开销
        switch currentState {
        case .daily(.idle), .daily(.sitting), .daily(.sleeping), .daily(.eating):
            // 静态状态：什么都不做，跳过物理计算
            break
        case .interrupt:
             // 喝水/报时：通常也是原地不动的
            break
        case .system(.focusMode):
            // 专注模式：也是静止的
            break
        default:
            // 只有 Walking, Falling, BlownByWind 等状态才需要跑物理逻辑
            // 【注意】如果你把 walkingToFocus 放在 update 里，这里要注意逻辑包含
             if isWalkingToFocusLocation {
                 updateWalkingToFocus(deltaTime: deltaTime)
             } else {
                 updatePhysics(deltaTime: deltaTime)
             }
        }
        
        // 2. AI 更新
        // ... AI 逻辑通常只是减法运算，开销很小，可以保留 ...
        if isWalkingToFocusLocation || currentState == .system(.focusMode) || (currentState.priority == 80) {
        } else {
            updateAI(deltaTime: deltaTime)
        }
    }
}
