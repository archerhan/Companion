//
//  PetSpriteNode.swift
//  Companion
//
//  Created by it on 2025/12/6.
//
import SpriteKit

enum PetAnimation: String, CaseIterable {
    case walk
    case idle
    case eat
    case drag
    case sleep
    case angry
    case front
    
    // 这个 key 用来在节点上管理动画动作，确保同一时间只有一种主动画在播放
    var animationKey: String {
        return "cat_black_\(self.rawValue)"
    }
}

class PetSpriteNode: SKSpriteNode {
    private var walkFrames: [SKTexture] = []
    private var animations: [PetAnimation: [SKTexture]] = [:]
    private var currentAnimation: PetAnimation?
    
    init(imageNamed name: String) {
        let texture = SKTexture(imageNamed: name)
        super.init(texture: texture, color: .clear, size: texture.size())
        loadAllAnimations()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 加载所有动画资源
    private func loadAllAnimations() {
        // 确保你的纹理图集名为 "PetAnimations.atlas"
        let petAtlas = SKTextureAtlas(named: "PetAnimations")
        
        // 遍历我们定义的所有动画类型
        for animationType in PetAnimation.allCases {
            var frames: [SKTexture] = []
            let texturePrefix = "cat_black_\(animationType.rawValue)-" // 例如: "cat_black_walk-"
            
            let textureNames = petAtlas.textureNames.filter {
                $0.starts(with: texturePrefix)
            }.sorted() // 排序确保动画帧顺序正确
            
            for textureName in textureNames {
                frames.append(petAtlas.textureNamed(textureName))
            }
            
            // 只有当找到了对应的帧时，才存入字典
            if !frames.isEmpty {
                animations[animationType] = frames
                print("成功加载动画: \(animationType.rawValue), 帧数: \(frames.count)")
            } else {
                print("警告: 未找到动画 '\(animationType.rawValue)' 的纹理资源，前缀为: \(texturePrefix)")
            }
        }
    }
    // 让方法可以接受一个重复次数的参数
    func playAnimation(_ type: PetAnimation, repeatsForever: Bool = true, timePerFrame: TimeInterval = 0.1, repeatCount: Int = 1) {
        guard currentAnimation != type else { return }
        guard let frames = animations[type], !frames.isEmpty else {
            print("错误: 无法播放动画 \(type.rawValue)，因为没有找到对应的动画帧。")
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
            // --- 核心修改在这里 ---
            // 如果 repeatCount > 1，就使用 repeat(action:count:)
            if repeatCount > 1 {
                let repeatAction = SKAction.repeat(animationAction, count: repeatCount)
                self.run(repeatAction, withKey: type.animationKey)
            } else {
                // 否则，只播放一次
                self.run(animationAction, withKey: type.animationKey)
            }
        }
        
        self.currentAnimation = type
    }
    
    /// 根据动画类型和每帧时长，精确计算出动画的总时长
    /// - Parameters:
    ///   - type: 动画枚举类型
    ///   - timePerFrame: 动画播放时设置的每帧时间，默认为 0.1
    /// - Returns: 动画总时长
    func getAnimationDuration(for type: PetAnimation, timePerFrame: TimeInterval = 0.1) -> TimeInterval {
        // 1. 获取该动画类型对应的所有帧
        guard let frames = animations[type] else {
            print("警告: 无法计算 \(type.rawValue) 的时长，未找到动画帧。返回默认值 2.0。")
            return 2.0 // 提供一个安全的默认值
        }
        
        // 2. 核心计算：帧数 * 每帧时间
        return TimeInterval(frames.count) * timePerFrame
    }
}
