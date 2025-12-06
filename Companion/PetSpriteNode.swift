//
//  PetSpriteNode.swift
//  Companion
//
//  Created by it on 2025/12/6.
//
import SpriteKit

class PetSpriteNode: SKSpriteNode {
    private var walkFrames: [SKTexture] = []
    init(imageNamed name: String) {
        let texture = SKTexture(imageNamed: name)
        super.init(texture: texture, color: .clear, size: texture.size())
        setupAnimations()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAnimations() {
        let petAtlas = SKTextureAtlas(named: "PetAnimations")
        var frames: [SKTexture] = []
        let textureNames = petAtlas.textureNames.sorted()
        for textureName in textureNames {
            if textureName.starts(with: "cat_black_walk-") {
                frames.append(petAtlas.textureNamed(textureName))
            }
        }
        self.walkFrames = frames
    }
    
    func startWalking() {
        guard !walkFrames.isEmpty else { return }
        let walkAnimation = SKAction.animate(with: walkFrames, timePerFrame: 0.1)
        let repeatWalk = SKAction.repeatForever(walkAnimation)
        self.run(repeatWalk, withKey: "walkingAnimation")
    }
    func stopAnimation() {
        self.removeAction(forKey: "walkingAnimation")
    }
    
    func wasPoked() {
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        self.run(SKAction.sequence([scaleUp, scaleDown]))
    }
}
