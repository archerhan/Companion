
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
    case falling
    case sleeping
}

class PetScene: SKScene {
    
    weak var viewController: ViewController?
    private var pet: PetSpriteNode!
    private var dragOffset: CGPoint = .zero
    private var lastKnownPetFrame: CGRect?
    private var petHorizontalSpeed: CGFloat = 30.0
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
    private let SLEEPING_DURATION_RANGE: ClosedRange<TimeInterval> = 30...60    // 每次睡觉持续 30-60 秒
    private let HUNGER_CYCLE_RANGE: ClosedRange<TimeInterval> = 120...300 // 每 2-5 分钟饿一次
    private let ANGRY_CLICK_THRESHOLD = 3 // 连续点击3次会生气
    private let DOUBLE_CLICK_INTERVAL: TimeInterval = 0.3 // 0.3秒内算连续点击
    
    // 添加必要的物理相关属性
    private var gravity: CGVector = CGVector(dx: 0, dy: -100) // 重力加速度
    private var petVelocity: CGPoint = .zero // 宠物速度
    private var lastFallUpdateTime: TimeInterval = 0 // 用于下坠更新的计时器
    
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        
        pet = PetSpriteNode(imageNamed: "cat_black_idle-0")
        pet.name = "desktopPet"
        pet.size = CGSize(width: 80, height: 80)
        pet.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let initialX = self.size.width / 2
        let initialY = pet.size.height / 2
        pet.position = CGPoint(x: initialX, y: initialY)
        
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
        
        // --- 处理下落状态 ---
        if currentState == .falling {
            // 应用重力
            petVelocity.y += CGFloat(gravity.dy) * CGFloat(deltaTime)
            
            // 应用水平速度（带一些阻力）
            petVelocity.x = petHorizontalSpeed * 0.8 // 添加阻力
            
            // 更新位置
            var newPosition = pet.position
            newPosition.x += petVelocity.x * CGFloat(deltaTime)
            newPosition.y += petVelocity.y * CGFloat(deltaTime)
            
            // 边界检查（防止宠物飞出屏幕）
            let petHalfWidth = pet.size.width / 2
            let petHalfHeight = pet.size.height / 2
            
            // 水平边界碰撞
            if newPosition.x - petHalfWidth <= 0 && petVelocity.x < 0 {
                newPosition.x = petHalfWidth
                petVelocity.x *= -0.5 // 反弹并损失能量
                petHorizontalSpeed *= -0.5
            } else if newPosition.x + petHalfWidth >= self.size.width && petVelocity.x > 0 {
                newPosition.x = self.size.width - petHalfWidth
                petVelocity.x *= -0.5
                petHorizontalSpeed *= -0.5
            }
            
            // 地面碰撞检查
            let groundY = 0.0 // 地面位置（在屏幕底部）
            if newPosition.y - petHalfHeight <= groundY && petVelocity.y < 0 {
                // 碰到地面了
                newPosition.y = groundY + petHalfHeight
                currentState = previousStateBeforeAction
                petVelocity = .zero
            }
            
            pet.position = newPosition
            
            // 更新方向（如果需要）
            if petVelocity.x != 0 {
                let shouldFaceRight = petVelocity.x > 0
                pet.xScale = abs(pet.xScale) * (shouldFaceRight ? 1.0 : -1.0)
            }
            
            return // 下落状态不执行其他状态的更新逻辑
        }
        
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
            print("开始坐着，持续 \(String(format: "%.1f", timeUntilNextStateChange)) 秒")
        case .sleeping:
            timeUntilNextStateChange = TimeInterval.random(in: SLEEPING_DURATION_RANGE)
            print("开始睡觉，持续 \(String(format: "%.1f", timeUntilNextStateChange)) 秒")
        default:
            // 其他状态不参与这个自动切换循环
            timeUntilNextStateChange = .greatestFiniteMagnitude
        }
    }

    
    private func resetHungerTimer() {
        timeUntilHungry = TimeInterval.random(in: HUNGER_CYCLE_RANGE)
        print("下一次吃饭在 \(String(format: "%.1f", timeUntilHungry)) 秒后")
    }
    
    private func handleAfterSleepingTransition() {
        // 随机选择sleeping结束后的下一个状态
        let nextStates: [PetState] = [.sitting, .walking, .idle]
        let randomIndex = Int.random(in: 0..<nextStates.count)
        let nextState = nextStates[randomIndex]
        
        currentState = nextState
        
        // 根据新状态设置动画
        switch nextState {
        case .walking:
            pet.playAnimation(.walk)
            print("睡醒后开始走路")
        case .idle:
            pet.playAnimation(.idle)
            print("睡醒后开始发呆")
        case .sitting:
            pet.playAnimation(.front)
            print("睡醒后开始坐着")
        default:
            break
        }
        
        // 重置状态计时器
        resetStateTimer()
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
        
        case .falling:
            // 使用拖拽的动画，或者你可以创建一个专门的 falling 动画
            pet.playAnimation(.drag) // 或者创建 .falling
            pet.alpha = 1.0
        
        case .sleeping:
            pet.playAnimation(.sleep)
            pet.alpha = 0.8
            
            // 睡觉时加上轻微的呼吸动画
            let breatheIn = SKAction.fadeAlpha(to: 0.7, duration: 1.5)
            let breatheOut = SKAction.fadeAlpha(to: 0.8, duration: 1.5)
            let breathing = SKAction.repeatForever(SKAction.sequence([breatheIn, breatheOut]))
            pet.run(breathing, withKey: "breathing")
            
            // 设置睡觉状态的持续时间
            let sleepDuration = TimeInterval.random(in: SLEEPING_DURATION_RANGE)
            print("开始睡觉，持续 \(String(format: "%.1f", sleepDuration)) 秒")
            
            run(SKAction.wait(forDuration: sleepDuration)) { [weak self] in
                guard let self = self else { return }
                
                if self.currentState == .sleeping {
                    // 停止呼吸动画
                    self.pet.removeAction(forKey: "breathing")
                    self.handleAfterSleepingTransition()
                }
            }
                
        case .eating:
            // --- 定义重复次数 ---
            let repeatCount = 10 // 让吃饭动画播放10次
            // 1. 播放动画时传入重复次数
            pet.playAnimation(.eat, repeatsForever: false, repeatCount: repeatCount)
            
            // 2. 计算时长时，要乘以重复次数
            let singleDuration = pet.getAnimationDuration(for: .eat)
            let totalDuration = singleDuration * TimeInterval(repeatCount)
            
            run(SKAction.wait(forDuration: totalDuration)) { [weak self] in
                guard let self = self else { return }
                // 吃完饭后就睡觉
                self.previousStateBeforeAction = self.currentState // 保存当前状态（eating）
                self.currentState = .sleeping
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
        
        // 处理特殊状态
        switch currentState {
        case .beingDragged:
            // 拖拽状态下需要鼠标交互
            window.ignoresMouseEvents = false
            NSCursor.pointingHand.set()
            return
            
        case .sleeping, .eating, .angry, .falling:
            // 这些特殊状态下，窗口忽略鼠标事件（鼠标穿透）
            window.ignoresMouseEvents = true
            NSCursor.arrow.set()
            return
            
        default:
            // 常规状态（walking, idle, sitting）
            break
        }
        
        // 常规状态下的鼠标检测
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
        
        // 如果在特殊状态中，不能开始新的拖拽
        // 添加更多特殊状态到排除列表
        let nonInteractiveStates: [PetState] = [.falling, .sleeping, .eating, .angry]
        if nonInteractiveStates.contains(currentState) {
            return
        }
        
        // --- 快速点击检测逻辑 ---
        let currentTime = event.timestamp
        if currentTime - lastMouseDownTime < DOUBLE_CLICK_INTERVAL {
            mouseDownCount += 1
        } else {
            mouseDownCount = 1
        }
        lastMouseDownTime = currentTime
        
        // 如果达到生气阈值，并且当前是日常状态
        let dailyStates: [PetState] = [.walking, .idle, .sitting]
        if mouseDownCount >= ANGRY_CLICK_THRESHOLD && dailyStates.contains(currentState) {
            mouseDownCount = 0 // 重置计数，防止下次单击就生气
            previousStateBeforeAction = currentState
            currentState = .angry
            return
        }
        
        // --- 正常的拖拽逻辑 ---
        // 只有在日常状态下才能开始拖拽
        if dailyStates.contains(currentState) {
            dragOffset = CGPoint(x: locationInScene.x - pet.position.x, y: locationInScene.y - pet.position.y)
            dragStartLocation = locationInScene
            previousStateBeforeAction = currentState
            self.currentState = .beingDragged
        }
    }

    
    // 在 mouseUp 方法中修改拖拽结束的逻辑
    override func mouseUp(with event: NSEvent) {
        if currentState == .beingDragged {
            // 记录松开时的速度（可以基于最后几次拖拽位置计算）
            if let lastDragLocation = dragStartLocation {
                let currentLoc = event.location(in: self)
//                let dragDuration = event.timestamp - lastMouseDownTime
                
                // 计算水平速度（保持原有逻辑）
                let totalDragDistanceX = currentLoc.x - lastDragLocation.x
                let dragThreshold: CGFloat = 10.0
                
                if totalDragDistanceX > dragThreshold {
                    petHorizontalSpeed = abs(petHorizontalSpeed)
                } else if totalDragDistanceX < -dragThreshold {
                    petHorizontalSpeed = -abs(petHorizontalSpeed)
                }
                
                // 设置垂直速度（模拟抛出效果）
                // 这里使用一个基础的下落速度，你可以根据需要调整
                petVelocity.y = -100 // 初始向上速度，然后受重力影响下落
                
                // 进入下落状态
                currentState = .falling
            }
            
            // 重置追踪变量
            dragStartLocation = nil
            
            let currentXScaleSign = pet.xScale.sign == .minus ? -1.0 : 1.0
            let scaleUp = SKAction.scaleX(to: 1.05 * currentXScaleSign, y: 1.05, duration: 0.1)
            let scaleDown = SKAction.scaleX(to: 1.0 * currentXScaleSign, y: 1.0, duration: 0.1)
            pet.run(SKAction.sequence([scaleUp, scaleDown]))
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

