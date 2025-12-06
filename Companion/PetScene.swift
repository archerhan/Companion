
//
//  PetScene.swift
//  Companion
//

import SpriteKit

enum PetState {
    case walking
    case idle
    case sitting
    case beingDragged
    case eating
    case angry
}

class PetScene: SKScene {
    
    weak var viewController: ViewController?
    private var pet: PetSpriteNode!
    private var dragOffset: CGPoint = .zero
    private var lastKnownPetFrame: CGRect?
    private var petHorizontalSpeed: CGFloat = 100.0
    private var lastUpdateTime: TimeInterval = 0
    private var dragStartLocation: CGPoint?
    
    // 引入状态机核心
    private var currentState: PetState = .idle {
        didSet {
            // 当状态改变时，执行相应的逻辑
            handleStateChange(from: oldValue, to: currentState)
        }
    }
    // 状态计时器：决定当前状态（如 walking 或 idle）持续多久
    private var timeUntilNextStateChange: TimeInterval = 0
    
    // 饥饿计时器：决定多久喂食一次
    private var timeUntilHungry: TimeInterval = 30.0 // 初始设为 60 秒后饿
    
    // 用于保存被“打断”前的状态（例如，吃完饭后要回去干嘛）
    private var previousStateBeforeAction: PetState = .walking
    
    // 用于检测快速点击
    private var lastMouseDownTime: TimeInterval = 0
    private var mouseDownCount: Int = 0
    
    // --- 常量定义，方便调整 ---
    private let WALK_DURATION_RANGE: ClosedRange<TimeInterval> = 10...20 // 每次走路持续 10-20 秒
    private let IDLE_DURATION_RANGE: ClosedRange<TimeInterval> = 3...8    // 每次发呆持续 3-8 秒
    private let SITTING_DURATION_RANGE: ClosedRange<TimeInterval> = 10...15    // 每次坐着持续 10-15 秒
    private let HUNGER_CYCLE_RANGE: ClosedRange<TimeInterval> = 40...100 // 每 2-5 分钟饿一次
    private let ANGRY_CLICK_THRESHOLD = 3 // 连续点击3次会生气
    private let DOUBLE_CLICK_INTERVAL: TimeInterval = 0.3 // 0.3秒内算连续点击
    
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        
        pet = PetSpriteNode(imageNamed: "cat_black_idle-0")
        pet.name = "desktopPet"
        pet.size = CGSize(width: 80, height: 80)
        pet.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        // 使用 self.size 来设置初始位置，确保与场景尺寸一致
        pet.position = CGPoint(x: self.size.width / 2, y: 200)
        self.addChild(pet)
        
        pet.playAnimation(.idle)
        resetStateTimer()
        resetHungerTimer() // 别忘了也初始化饥饿计时器
        
        updatePetDirection()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let vc = self.viewController, let petNode = self.pet else { return }
            vc.updateTrackingArea(for: petNode)
            self.lastKnownPetFrame = petNode.frame
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        updateMouseInteraction()
        
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // --- 更新计时器 ---
        if currentState == .walking || currentState == .idle || currentState == .sitting {
            timeUntilNextStateChange -= deltaTime
            timeUntilHungry -= deltaTime
            
            // 检查是否饿了 (优先级更高)
            if timeUntilHungry <= 0 {
                previousStateBeforeAction = currentState
                currentState = .eating
                return // 进入吃饭状态，本帧不再做其他事
            }
            
            // 检查是否需要切换走路/发呆状态
            if timeUntilNextStateChange <= 0 {
                if currentState == .walking {
                    currentState = .idle
                } else if currentState == .idle {
                    currentState = .sitting
                } else {
                    currentState = .walking
                }
                resetStateTimer() // 重置新状态的持续时间
            }
        }
        
        guard currentState == .walking else {
            return
        }
        let petHalfWidth = pet.size.width / 2
        if (pet.position.x - petHalfWidth <= 0 && petHorizontalSpeed < 0) ||
           (pet.position.x + petHalfWidth >= self.size.width && petHorizontalSpeed > 0) {
            petHorizontalSpeed *= -1
            updatePetDirection()
        }
        pet.position.x += petHorizontalSpeed * CGFloat(deltaTime)
    }
    
    // --- 新增辅助方法 ---
    private func resetStateTimer() {
        switch currentState {
        case .walking:
            timeUntilNextStateChange = TimeInterval.random(in: WALK_DURATION_RANGE)
            print("开始走路，持续 \(String(format: "%.1f", timeUntilNextStateChange)) 秒")
        case .idle:
            timeUntilNextStateChange = TimeInterval.random(in: IDLE_DURATION_RANGE)
            print("开始发呆，持续 \(String(format: "%.1f", timeUntilNextStateChange)) 秒")
        case .sitting:
            timeUntilNextStateChange = TimeInterval.random(in: SITTING_DURATION_RANGE)
            print("开始发呆，持续 \(String(format: "%.1f", timeUntilNextStateChange)) 秒")
        default:
            // 其他状态（如拖拽、吃饭）不参与这个自动切换循环
            timeUntilNextStateChange = .greatestFiniteMagnitude // 设置一个极大值，防止意外切换
        }
    }
    
    private func resetHungerTimer() {
        timeUntilHungry = TimeInterval.random(in: HUNGER_CYCLE_RANGE)
        print("下一次吃饭在 \(String(format: "%.1f", timeUntilHungry)) 秒后")
    }
    
    /// 核心的状态处理函数
    private func handleStateChange(from oldState: PetState, to newState: PetState) {
        guard oldState != newState else { return }
        print("状态改变: 从 \(oldState) -> 到 \(newState)")
        
        switch newState {
        // ... walking, idle, beingDragged 状态不变 ...
        case .walking:
            pet.playAnimation(.walk)
            pet.alpha = 1.0
            
        case .idle:
            pet.playAnimation(.idle)
            pet.alpha = 1.0
            
        case .sitting:
            pet.playAnimation(.front)
            pet.alpha = 1.0
            
        case .beingDragged:
            pet.playAnimation(.drag)
            pet.alpha = 0.8
                
        case .eating:
            // --- 定义重复次数 ---
            let repeatCount = 3 // 让吃饭动画播放3次
            // 1. 播放动画时传入重复次数
            pet.playAnimation(.eat, repeatsForever: false, repeatCount: repeatCount)
            
            // 2. 计算时长时，要乘以重复次数
            let singleDuration = pet.getAnimationDuration(for: .eat)
            let totalDuration = singleDuration * TimeInterval(repeatCount)
            
            run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
                guard let self = self else { return }
                self.currentState = self.previousStateBeforeAction
                self.resetHungerTimer()
            }
                
        case .angry:
            let repeatCount = 2
            pet.playAnimation(.angry, repeatsForever: false, repeatCount: repeatCount)
            
            // 计算总时长时，需要乘以重复次数
            let singleDuration = pet.getAnimationDuration(for: .angry)
            let totalDuration = singleDuration * TimeInterval(repeatCount)
            
            run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
                guard let self = self else { return }
                if self.currentState == .angry {
                    self.currentState = self.previousStateBeforeAction
                }
            }
        }
    }
    
    private func updateMouseInteraction() {
        guard let window = self.view?.window, let skView = self.view else { return }
        if currentState == .beingDragged {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
            return
        }
        
        let mouseLocationInWindow = window.mouseLocationOutsideOfEventStream
        let mouseLocationInView = skView.convert(mouseLocationInWindow, from: nil)
        let mouseLocationInScene = self.convertPoint(fromView: mouseLocationInView)
        let isMouseOnPet = pet.frame.contains(mouseLocationInScene)
        if isMouseOnPet {
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
        } else {
            window.ignoresMouseEvents = true
            NSCursor.arrow.set()
        }
    }
    
    private func updatePetDirection() {
        if petHorizontalSpeed > 0 {
            pet.xScale = abs(pet.xScale)
        } else {
            pet.xScale = -abs(pet.xScale)
        }
    }
    
    override func didFinishUpdate() {
        guard let petNode = self.pet, let viewController = self.viewController else {
            return
        }
        
        let currentPetFrame = petNode.frame
        if lastKnownPetFrame == nil || lastKnownPetFrame != currentPetFrame {
            DispatchQueue.main.async {
                viewController.updateTrackingArea(for: petNode)
            }
            self.lastKnownPetFrame = currentPetFrame
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInScene = event.location(in: self)
        // 检查是否点击在宠物身上
        guard atPoint(locationInScene).name == "desktopPet" else { return }
        
        // --- 快速点击检测逻辑 ---
        let currentTime = event.timestamp
        if currentTime - lastMouseDownTime < DOUBLE_CLICK_INTERVAL {
            mouseDownCount += 1
        } else {
            mouseDownCount = 1
        }
        lastMouseDownTime = currentTime
        
        // 如果达到生气阈值，并且当前不是正在执行特殊动作（如吃饭、拖拽）
        if mouseDownCount >= ANGRY_CLICK_THRESHOLD && (currentState == .walking || currentState == .idle) {
            mouseDownCount = 0 // 重置计数，防止下次单击就生气
            previousStateBeforeAction = currentState
            currentState = .angry
            return // << --- 关键！进入生气状态后，立刻结束本次点击事件处理
        }
        
        // --- 正常的拖拽逻辑 ---
        // 只有在非特殊动作状态下才能开始拖拽
        if currentState != .eating && currentState != .angry {
            dragOffset = CGPoint(x: locationInScene.x - pet.position.x, y: locationInScene.y - pet.position.y)
            dragStartLocation = locationInScene
            
            previousStateBeforeAction = currentState
            self.currentState = .beingDragged
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if currentState == .beingDragged  {
            // --- 状态机切换 ---
            // 拖拽结束后，让它恢复到被拖拽前的状态
            self.currentState = previousStateBeforeAction
            
            if let startLoc = dragStartLocation {
                let currentLoc = event.location(in: self)
                let totalDragDistanceX = currentLoc.x - startLoc.x
                
                // 设置一个更大的阈值，以区分真正的“拖拽”和“点击”
                let dragThreshold: CGFloat = 10.0
                
                print("拖拽距离: \(totalDragDistanceX)")

                if totalDragDistanceX > dragThreshold {
                    // 明确向右拖拽
                    petHorizontalSpeed = abs(petHorizontalSpeed)
                    print("判断为向右拖拽")
                } else if totalDragDistanceX < -dragThreshold {
                    // 明确向左拖拽
                    petHorizontalSpeed = -abs(petHorizontalSpeed)
                    print("判断为向左拖拽")
                }
                // 如果拖拽距离很小 (在阈值内), 则不改变方向，视为点击或微小移动
                
                updatePetDirection() // 根据新的速度方向更新宠物朝向
            }
            
            // 重置追踪变量
            dragStartLocation = nil
            
            // 动画代码
            let currentXScaleSign = pet.xScale.sign == .minus ? -1.0 : 1.0
            let scaleUp = SKAction.scaleX(to: 1.05 * currentXScaleSign, y: 1.05, duration: 0.1)
            let scaleDown = SKAction.scaleX(to: 1.0 * currentXScaleSign, y: 1.0, duration: 0.1)
            pet.run(SKAction.sequence([scaleUp, scaleDown]))
            
            print("结束拖动宠物，新速度方向: \(petHorizontalSpeed > 0 ? "向右" : "向左")")
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if currentState == .beingDragged {
            let newLocation = event.location(in: self)
            var newPosition = CGPoint(
                x: newLocation.x - dragOffset.x,
                y: newLocation.y - dragOffset.y
            )
            
            // --- 核心修复：添加边界限制 ---
            let petHalfWidth = pet.size.width / 2
            let petHalfHeight = pet.size.height / 2
            
            // 限制水平位置
            let minX = petHalfWidth
            let maxX = self.size.width - petHalfWidth
            newPosition.x = max(minX, min(newPosition.x, maxX))
            
            // 限制垂直位置
            let minY = petHalfHeight
            let maxY = self.size.height - petHalfHeight
            newPosition.y = max(minY, min(newPosition.y, maxY))
            
            // --- 直接设置位置，而不是用 SKAction ---
            pet.position = newPosition
        }
    }
}

