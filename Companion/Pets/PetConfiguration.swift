//
//  PetFactory.swift
//  Companion
//
//  Created by it on 2025/12/9.
//

// PetConfiguration.swift - 配置系统
import SpriteKit

// MARK: - 宠物配置协议
protocol PetConfiguration {
    var petType: PetType { get }
    var baseName: String { get }
    var textureAtlasName: String { get }
    var defaultSize: CGSize { get }
    var walkSpeedRange: ClosedRange<CGFloat> { get }
    
    // 每个大类下可用的具体状态
    var availableStates: [PetState] { get }
    
    // 状态持续时间
    func stateDuration(for state: PetState) -> ClosedRange<TimeInterval>
    
    // 辅助方法：获取某大类下的所有状态
    func states(in category: PetState.Category) -> [PetState]
}

// MARK: - 宠物状态分类扩展
extension PetState {
    enum Category {
        case daily, interrupt, nonInteractive, play
    }
    
    var category: Category {
        switch self {
        case .daily: return .daily
        case .interrupt: return .interrupt
        case .nonInteractive: return .nonInteractive
        case .play: return .play
        }
    }
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

// MARK: - 配置基类
class BasePetConfiguration: PetConfiguration {
    let petType: PetType
    let baseName: String
    var textureAtlasName: String = "PetAnimations"
    let defaultSize: CGSize
    let walkSpeedRange: ClosedRange<CGFloat>
    
    // 子类需要重写这些
    var availableStates: [PetState] { [] }
    
    init(
        petType: PetType,
        baseName: String,
        textureAtlasName: String,
        defaultSize: CGSize,
        walkSpeedRange: ClosedRange<CGFloat>
    ) {
        self.petType = petType
        self.baseName = baseName
        self.textureAtlasName = textureAtlasName
        self.defaultSize = defaultSize
        self.walkSpeedRange = walkSpeedRange
    }
    
    func stateDuration(for state: PetState) -> ClosedRange<TimeInterval> {
        // 默认持续时间
        return 3...5
    }
    
    func states(in category: PetState.Category) -> [PetState] {
        return availableStates.filter { $0.category == category }
    }
}

// MARK: - 具体宠物配置
final class CatBlackConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .catBlack,
            baseName: "cat_black",
            textureAtlasName: "CatBlackAnimations",
            defaultSize: CGSize(width: 80, height: 80),
            walkSpeedRange: 25...35
        )
    }
    
    override var availableStates: [PetState] {
        return [
            .daily(.walking),
            .daily(.idle),
            .daily(.sitting),
            .interrupt(.eating),
            .nonInteractive(.falling),
            .nonInteractive(.beingDragged),
        ]
    }
    
    override func stateDuration(for state: PetState) -> ClosedRange<TimeInterval> {
        switch state {
        case .daily(let dailyState):
            switch dailyState {
            case .walking: return 10...20
            case .idle: return 3...8
            case .sitting: return 10...15
            case .sleeping: return 30...60
            }
        case .interrupt(.eating): return 5...10
        default: return 3...5
        }
    }
}

final class PenguinConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .penguin,
            baseName: "penguin",
            textureAtlasName: "PenguinAnimations",
            defaultSize: CGSize(width: 75, height: 75),
            walkSpeedRange: 20...30
        )
    }
    
    override var availableStates: [PetState] {
        return [
            .daily(.walking),
            .interrupt(.eating),
            .nonInteractive(.falling),
            .nonInteractive(.beingDragged),
            .play(.sliding),
        ]
    }
    
    override func stateDuration(for state: PetState) -> ClosedRange<TimeInterval> {
        switch state {
        case .daily(let dailyState):
            switch dailyState {
            case .walking: return 8...15
            case .idle: return 4...10
            case .sitting: return 15...20
            case .sleeping: return 40...70
            }
        case .interrupt(.eating): return 6...12
        default: return 3...5
        }
    }
}
