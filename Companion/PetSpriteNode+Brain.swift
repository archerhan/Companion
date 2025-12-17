//
//  PetSpriteNode+Brain.swift
//  Companion
//
//  Created by it on 2025/12/15.
//

import SpriteKit

extension PetSpriteNode {
    
    // MARK: - AI 决策
    
    func updateAI(deltaTime: TimeInterval) {
        guard currentState.priority == 0 else { return }
        
        timeUntilNextRandomAction -= deltaTime
        if timeUntilNextRandomAction <= 0 {
            pickRandomDailyState()
        }
    }
    
    func pickRandomDailyState() {
        let allowedStates = configuration.capableRandomStates
        guard let randomState = allowedStates.randomElement() else { return }
        trySwitchState(to: randomState)
    }
    
    // MARK: - 状态进入响应 (The Brain Reaction)
    
    func handleStateEnter(_ state: PetState) {
        // 1. 播放动画
        playAnimation(state.animation, loop: state.isLooping)
        
        // 2. 重置物理参数 (Brain 指挥 Physics)
        switch state {
        case .environment(.falling):
            zRotation = .zero
            if previousState == .environment(.stuckOnEdge) { petVelocity = .zero }
        case .environment(.blownByWind):
            resetWindParams() // 逻辑在 Physics，但在这里触发
        case .environment(.stuckOnEdge):
            petVelocity = .zero
        case .daily(.walking):
            if petHorizontalSpeed == 0 {
                petHorizontalSpeed = 30 * (Bool.random() ? 1.0 : -1.0)
            }
            updateDirection()
        default: break
        }
        
        // 3. 气泡与 UI
        if case .interrupt(.hourlyChime) = state { showTimeBubble() }
        else if case .interrupt(.waterReminder) = state { showWaterBubble() }
        else {
            // 【修复】只有在"不是"前往专注地点的路上时，才隐藏气泡
            // 否则会把专注倒计时给隐藏掉，导致闪烁
            if !isWalkingToFocusLocation {
                bubbleNode.hide()
            }
        }
        
        // 4. 定时器与自动退出逻辑
        let range = configuration.durationRange(for: state)
        let duration = TimeInterval.random(in: range)
        timeUntilNextRandomAction = duration
        
        switch state {
        case .interrupt:
            // 喝水/报时：必须退出
            let wait = SKAction.wait(forDuration: duration)
            let exit = SKAction.run { [weak self] in
                guard let self = self else { return }
                if self.isPomodoroActive {
                    // 智能启动专注
                    self.startFocusMode()
                } else {
                    self.trySwitchState(to: .daily(.idle), force: true)
                }
            }
            run(SKAction.sequence([wait, exit]), withKey: "AutoExitState")
            
        case .system(let s):
            // 烦躁/低电量：自动恢复
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
            // 物理状态：绝对禁止自动退出
            removeAction(forKey: "AutoExitState")
            
        case .daily, .play:
            removeAction(forKey: "AutoExitState")
        }
        
        // 5. 落地后自动专注检测
        if isPomodoroActive, case .daily = state {
            let wait = SKAction.wait(forDuration: 1.0)
            let goFocus = SKAction.run { [weak self] in
                guard let self = self, self.isPomodoroActive else { return }
                self.startFocusMode()
            }
            run(SKAction.sequence([wait, goFocus]))
        }
    }
    
    // 辅助方法：重置风参数
    private func resetWindParams() {
        flightTime = 0
        windPhaseOffset = Double.random(in: 0...(2 * .pi))
        windFrequencySlow = Double.random(in: 1.0...2.0)
        windFrequencyFast = Double.random(in: 3.0...5.0)
        windAmplitude = CGFloat.random(in: 300...500)
        verticalLiftSpeed = CGFloat.random(in: 50...100)
        petVelocity = CGPoint(x: 0, y: verticalLiftSpeed)
        self.physicsBody?.affectedByGravity = false
    }
    
    // MARK: - 专注控制
    
    func startFocusMode() {
        if case .environment = currentState { return }
        
        guard let parent = parent else { return }
        let targetX = parent.frame.width - 50
        let targetY = size.height / 2
        focusTargetLocation = CGPoint(x: targetX, y: targetY)
        
        let distance = abs(targetX - position.x)
        
        if distance < 20 {
            isWalkingToFocusLocation = false
            trySwitchState(to: .system(.focusMode), force: true)
            playAnimation(.front)
        } else {
            isWalkingToFocusLocation = true
            trySwitchState(to: .daily(.walking), force: true)
        }
    }
    
    func endFocusMode() {
        isWalkingToFocusLocation = false
        focusTargetLocation = nil
        trySwitchState(to: .daily(.idle), force: true)
        bubbleNode.show(text: "完成啦！🎉", at: CGPoint(x: 0, y: size.height/2 + 15))
    }
    
    func tryRescue() -> Bool {
        if case .environment(.stuckOnEdge) = currentState {
            trySwitchState(to: .environment(.falling), force: true)
            // 【修改】检查音效
            if AppConfig.enableSound {
               // 播放一个解救成功的音效，比如 pop 声
                NSSound(named: "Pop")?.play()
            }
            return true
        }
        return false
    }
    
    // 供外部调用
    func triggerSystemEvent(_ event: PetState.SystemState) {
        trySwitchState(to: .system(event))
    }
    
    func triggerSystemEvent(_ type: PetState.InterruptState) {
       trySwitchState(to: .interrupt(type))
    }
    
    func triggerWind() {
        trySwitchState(to: .environment(.blownByWind), force: true)
    }
}
