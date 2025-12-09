//
//  PetFactory.swift
//  Companion
//
//  Created by it on 2025/12/9.
//

// PetConfiguration.swift - 宠物配置协议
import SpriteKit

// MARK: - 宠物配置协议
protocol PetConfiguration {
    var petType: PetType { get }
    var baseName: String { get }
    var animations: [PetAnimation] { get }
    var textureAtlasName: String { get }
    var defaultSize: CGSize { get }
    var walkSpeedRange: ClosedRange<CGFloat> { get }
    var stateDurations: [PetState: ClosedRange<TimeInterval>] { get }
}

// MARK: - 宠物类型
enum PetType: String, CaseIterable {
    case catBlack = "cat_black"
    case penguin = "penguin"
    // 可以继续添加更多类型
    
    static func configuration(for type: PetType) -> PetConfiguration {
        switch type {
        case .catBlack:
            return CatBlackConfiguration()
        case .penguin:
            return PenguinConfiguration()
        }
    }
}

// MARK: - 具体宠物配置
struct CatBlackConfiguration: PetConfiguration {
    let petType: PetType = .catBlack
    let baseName: String = "cat_black"
    let animations: [PetAnimation] = PetAnimation.allCases
    let textureAtlasName: String = "PenguinAnimations"
    let defaultSize: CGSize = CGSize(width: 80, height: 80)
    
    let walkSpeedRange: ClosedRange<CGFloat> = 25...35
    let stateDurations: [PetState: ClosedRange<TimeInterval>] = [
        .walking: 10...20,
        .idle: 3...8,
        .sitting: 10...15,
        .sleeping: 30...60,
        .eating: 5...10
    ]
}

struct PenguinConfiguration: PetConfiguration {
    let petType: PetType = .penguin
    let baseName: String = "penguin"
    let animations: [PetAnimation] = PetAnimation.allCases
    let textureAtlasName: String = "PenguinAnimations"
    let defaultSize: CGSize = CGSize(width: 75, height: 75)
    
    let walkSpeedRange: ClosedRange<CGFloat> = 20...30
    let stateDurations: [PetState: ClosedRange<TimeInterval>] = [
        .walking: 8...15,
        .idle: 4...10,
        .sitting: 15...20,
        .sleeping: 40...70,
        .eating: 6...12
    ]
}

// MARK: - 宠物工厂
class PetFactory {
    static func createPet(of type: PetType) -> PetSpriteNode {
        let config = PetType.configuration(for: type)
        return PetSpriteNode(configuration: config)
    }
    
    static func createRandomPet() -> PetSpriteNode {
        let types = PetType.allCases
        let randomIndex = Int.random(in: 0..<types.count)
        return createPet(of: types[randomIndex])
    }
}
