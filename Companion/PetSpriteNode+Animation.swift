//
//  PetSpriteNode+Animation.swift
//  Companion
//
//  Created by it on 2025/12/15.
//

import SpriteKit

extension PetSpriteNode {
    
    func loadAnimations() {
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
        
        currentAnimationType = type
        removeAction(forKey: "anim")
        
        let animateAction = SKAction.animate(with: frames, timePerFrame: 0.12)
        
        if loop {
            let repeatAction = SKAction.repeatForever(animateAction)
            run(repeatAction, withKey: "anim")
        } else {
            let completionBlock = SKAction.run { [weak self] in
                self?.animationDidFinish()
            }
            let sequence = SKAction.sequence([animateAction, completionBlock])
            run(sequence, withKey: "anim")
        }
    }
    
    func animationDidFinish() {
        // 动画结束回调
        if currentState.priority >= 70 { // Interrupt
            // 可以在这里处理逻辑，不过目前主要依赖 Brain 中的 Timer 退出
            // 这里留空或做备用降级
        }
    }
    
    // MARK: - 朝向控制
    
    func updateDirection() {
        var targetDirection: CGFloat = 0
        
        if case .environment(.beingDragged) = currentState {
            targetDirection = currentDragDirection
        } else if case .daily(.walking) = currentState {
            targetDirection = petHorizontalSpeed
        } else if case .environment(.blownByWind) = currentState {
            targetDirection = petVelocity.x
        } else {
            if abs(petVelocity.x) > 0.1 { targetDirection = petVelocity.x }
        }
        
        guard abs(targetDirection) > 0.1 else { return }
        
        let shouldFaceRight = targetDirection > 0
        let isAssetFacingRight = configuration.isTextureFacingRight
        let multiplier: CGFloat = (shouldFaceRight == isAssetFacingRight) ? 1.0 : -1.0
        
        let newXScale = abs(xScale) * multiplier
        if xScale != newXScale {
            xScale = newXScale
            bubbleNode.xScale = (xScale < 0) ? -1 : 1
        }
    }
    
    // MARK: - 气泡显示逻辑
    
    func showTimeBubble() {
        let hour = Calendar.current.component(.hour, from: Date())
        let text: String
        if hour == 0 {
            text = "bubble_midnight".localized
        } else if hour < 6 {
            text = "bubble_early_morning".localized(with: hour)
        } else if hour == 12 {
            text = "bubble_noon".localized
        } else {
            text = "bubble_hourly_format".localized(with: hour)
        }
        
        bubbleNode.show(text: text, at: CGPoint(x: 0, y: size.height/2 + 15))
    }
    
    func showWaterBubble() {
        let keys = ["bubble_water_1", "bubble_water_2", "bubble_water_3", "bubble_water_4"]
        let randomKey = keys.randomElement() ?? "bubble_water_1"
        bubbleNode.show(text: randomKey.localized, at: CGPoint(x: 0, y: size.height/2 + 15))
    }
    
    func updateFocusTimerBubble(text: String) {
        if case .interrupt = currentState { return }
        
        if case .system(.focusMode) = currentState {
            bubbleNode.position = CGPoint(x: 0, y: size.height/2 + 15)
            bubbleNode.updateText(text)
        } else if isWalkingToFocusLocation {
            bubbleNode.position = CGPoint(x: 0, y: size.height/2 + 15)
            bubbleNode.updateText(text)
        }
    }
}
