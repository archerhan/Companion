//
//  PetSpriteNode+Physics.swift
//  Companion
//
//  Created by it on 2025/12/15.
//

import SpriteKit

extension PetSpriteNode {
    
    // MARK: - 物理主入口
    func updatePhysics(deltaTime: TimeInterval) {
        switch currentState {
        case .daily(.walking):
            updateWalking(deltaTime: deltaTime)
        case .environment(.falling):
            updateGravity(deltaTime: deltaTime)
        case .environment(.blownByWind):
            updateWindPhysics(deltaTime: deltaTime)
        case .environment(.stuckOnEdge):
            break
        case .environment(.beingDragged):
            break
        default:
            break
        }
    }
    
    // MARK: - 具体的物理行为
    
    func updateWalking(deltaTime: TimeInterval) {
        let parentWidth = parent?.frame.width ?? 800
        let halfWidth = size.width / 2
        
        position.x += petHorizontalSpeed * CGFloat(deltaTime)
        
        if (position.x - halfWidth <= 0 && petHorizontalSpeed < 0) ||
           (position.x + halfWidth >= parentWidth && petHorizontalSpeed > 0) {
            petHorizontalSpeed *= -1
            updateDirection() // 在 +Animation.swift
        }
    }
    
    func updateWalkingToFocus(deltaTime: TimeInterval) {
        guard let target = focusTargetLocation else { return }
        
        // 1. 简单的物理下落
        if position.y > size.height/2 + 2 {
            let gravity: CGFloat = -1500
            petVelocity.y += gravity * CGFloat(deltaTime)
            position.y += petVelocity.y * CGFloat(deltaTime)
            
            if position.y <= size.height/2 {
                position.y = size.height/2
                petVelocity.y = 0
                playAnimation(.walk)
            } else {
                playAnimation(.drag)
                return
            }
        }
        
        // 2. 水平移动
        let distance = target.x - position.x
        
        if abs(distance) < 10 {
            // 到达
            isWalkingToFocusLocation = false
            focusTargetLocation = nil
            petVelocity = .zero
            trySwitchState(to: .system(.focusMode), force: true)
            playAnimation(.front)
        } else {
            // 继续走
            let direction: CGFloat = distance > 0 ? 1.0 : -1.0
            let walkSpeed: CGFloat = 60.0
            position.x += walkSpeed * direction * CGFloat(deltaTime)
            
            if xScale * direction < 0 {
                xScale = abs(xScale) * direction
                bubbleNode.xScale = (xScale < 0) ? -1 : 1
            }
            playAnimation(.walk)
        }
    }
    
    func updateGravity(deltaTime: TimeInterval) {
        let gravity: CGFloat = -1500
        petVelocity.y += gravity * CGFloat(deltaTime)
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        let groundY: CGFloat = size.height/2
        if position.y <= groundY {
            position.y = groundY
            
            if abs(petVelocity.x) > 10 {
                let landingDir: CGFloat = petVelocity.x > 0 ? 1.0 : -1.0
                petHorizontalSpeed = abs(petHorizontalSpeed) * landingDir
            }
            
            petVelocity = .zero
            trySwitchState(to: .daily(.walking), force: true)
        }
        
        _ = handleWallBounce()
    }
    
    func updateWindPhysics(deltaTime: TimeInterval) {
        guard let parent = parent else { return }
        
        flightTime += deltaTime
        
        let slowWave = sin(flightTime * windFrequencySlow + windPhaseOffset)
        let fastWave = sin(flightTime * windFrequencyFast) * 0.3
        let noise = CGFloat.random(in: -20...20)
        
        petVelocity.x = (CGFloat(slowWave + fastWave) * windAmplitude) + noise
        
        let liftVariation = sin(flightTime * 3.0) * 30
        petVelocity.y = verticalLiftSpeed + CGFloat(liftVariation)
        
        position.x += petVelocity.x * CGFloat(deltaTime)
        position.y += petVelocity.y * CGFloat(deltaTime)
        
        let targetRotation = -petVelocity.x * 0.002
        let maxRotation = CGFloat.pi / 4
        zRotation = targetRotation.clamped(to: -maxRotation...maxRotation)
        
        checkStuckOnEdge(parentFrame: parent.frame)
    }
    
    // MARK: - 辅助检测
    
    func checkStuckOnEdge(parentFrame: CGRect) {
        let halfW = size.width / 2
        let halfH = size.height / 2
        let stickHeightThreshold = parentFrame.height * 0.5
        
        var isStuck = false
        var stuckPos = position
        
        if position.x - halfW <= 0 {
            position.x = halfW
            if position.y > stickHeightThreshold {
                stuckPos.x = halfW
                isStuck = true
            } else {
                if petVelocity.x < 0 { petVelocity.x = abs(petVelocity.x) * 0.5 }
            }
        } else if position.x + halfW >= parentFrame.width {
            position.x = parentFrame.width - halfW
            if position.y > stickHeightThreshold {
                stuckPos.x = parentFrame.width - halfW
                isStuck = true
            } else {
                if petVelocity.x > 0 { petVelocity.x = -abs(petVelocity.x) * 0.5 }
            }
        } else if position.y + halfH >= parentFrame.height {
            stuckPos.y = parentFrame.height - halfH
            isStuck = true
        }
        
        if isStuck {
            position = stuckPos
            zRotation = 0
            trySwitchState(to: .environment(.stuckOnEdge), force: true)
        }
    }
    
    private func handleWallBounce() -> Bool {
        let parentWidth = parent?.frame.width ?? 800
        let halfWidth = size.width / 2
        var bounced = false
        
        if position.x - halfWidth <= 0 && petVelocity.x < 0 {
            position.x = halfWidth
            petVelocity.x *= -0.6
            bounced = true
        } else if position.x + halfWidth >= parentWidth && petVelocity.x > 0 {
            position.x = parentWidth - halfWidth
            petVelocity.x *= -0.6
            bounced = true
        }
        
        if bounced { updateDirection() }
        return bounced
    }
    
    // MARK: - 拖拽接口
    
    func startDrag() {
        trySwitchState(to: .environment(.beingDragged), force: true)
    }
    
    func endDrag(velocity: CGPoint) {
        self.petVelocity = velocity
        
        let targetDirection: CGFloat
        if abs(velocity.x) > 10 {
            targetDirection = velocity.x
        } else {
            targetDirection = currentDragDirection
        }
        
        let directionSign: CGFloat = targetDirection > 0 ? 1.0 : -1.0
        petHorizontalSpeed = abs(petHorizontalSpeed) * directionSign
        
        trySwitchState(to: .environment(.falling), force: true)
    }
    
    func updateDragFacing(deltaX: CGFloat) {
        guard deltaX != 0 else { return }
        currentDragDirection = deltaX
        updateDirection()
    }
}
