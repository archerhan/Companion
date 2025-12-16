import SpriteKit

// MARK: - 1. 宠物类型
enum PetType: String, CaseIterable {
    case catBlack = "cat_black"
    case penguin = "penguin"
    
    var configuration: PetConfiguration {
        switch self {
        case .catBlack: return CatBlackConfiguration()
        case .penguin: return PenguinConfiguration()
        }
    }
}

// MARK: - 2. 配置协议
protocol PetConfiguration {
    var petType: PetType { get }
    var baseName: String { get }
    var textureAtlasName: String { get }
    var defaultSize: CGSize { get }
    var walkSpeedRange: ClosedRange<CGFloat> { get }
    var capableRandomStates: [PetState] { get }
    var isTextureFacingRight: Bool { get }
    func durationRange(for state: PetState) -> ClosedRange<TimeInterval>
}

// MARK: - 3. 基类实现
class BasePetConfiguration: PetConfiguration {
    let petType: PetType
    let baseName: String
    let textureAtlasName: String
    let defaultSize: CGSize
    let walkSpeedRange: ClosedRange<CGFloat>
    var isTextureFacingRight: Bool { return true }
    
    init(petType: PetType, baseName: String, textureAtlasName: String, defaultSize: CGSize, walkSpeedRange: ClosedRange<CGFloat>) {
        self.petType = petType
        self.baseName = baseName
        self.textureAtlasName = textureAtlasName
        self.defaultSize = defaultSize
        self.walkSpeedRange = walkSpeedRange
    }
    
    var capableRandomStates: [PetState] {
        return [.daily(.idle), .daily(.walking), .daily(.sitting), .daily(.sleeping)]
    }
    
    func durationRange(for state: PetState) -> ClosedRange<TimeInterval> {
        switch state {
        case .daily(let s):
            switch s {
            case .idle:     return 5...8
            case .walking:  return 30...50
            case .sitting:  return 15...30
            case .sleeping: return 50...80
            case .eating:   return 8...15
            }
        case .play: return 3...5
        case .system(.focusMode): return 1500...1500
        case .system: return 5...10
        case .environment: return 1000...1000 // 无限长，由物理逻辑控制
        case .interrupt(.waterReminder): return 10...10 // 10秒提醒
        case .interrupt(.hourlyChime): return 8...8
        }
    }
}

// MARK: - 4. 具体宠物
final class CatBlackConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .catBlack,
            baseName: "cat_black",
            textureAtlasName: "CatBlack",
            defaultSize: CGSize(width: 80, height: 80),
            walkSpeedRange: 40...40
        )
    }
    
    override var capableRandomStates: [PetState] {
        return [
            .daily(.idle),
            .daily(.walking),
            .daily(.walking),
            .daily(.eating),
            .daily(.sitting),
            .daily(.sleeping)
        ]
    }
    
    override func durationRange(for state: PetState) -> ClosedRange<TimeInterval> {
        switch state {
        case .daily(let s):
            switch s {
            case .idle:     return 5...8
            case .walking:  return 30...50
            case .sitting:  return 8...12
            case .sleeping: return 50...80
            case .eating:   return 8...15
            }
        case .play: return 3...5
        case .system(.focusMode): return 1500...1500
        case .system: return 5...10
        case .environment: return 1000...1000 // 无限长，由物理逻辑控制
        case .interrupt(.waterReminder): return 10...10 // 10秒提醒
        case .interrupt(.hourlyChime): return 10...10
        }
    }
}

final class PenguinConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .penguin,
            baseName: "penguin",
            textureAtlasName: "Penguin",
            defaultSize: CGSize(width: 60, height: 60),
            walkSpeedRange: 15...25
        )
    }
    override var capableRandomStates: [PetState] {
        return [.daily(.idle), .daily(.walking), .play(.sliding)]
    }
}
