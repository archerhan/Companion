//
//  PetConfiguration.swift
//  DesktopPet
//
//  Created by DesignAssistant on 2025/12/13.
//

import SpriteKit

// MARK: - 1. 宠物类型定义
enum PetType: String, CaseIterable {
    case catBlack = "cat_black"
    case penguin = "penguin"
    // 在这里添加更多宠物，例如: case shibaInu = "shiba_inu"
    
    /// 工厂方法：获取对应的配置实例
    var configuration: PetConfiguration {
        switch self {
        case .catBlack: return CatBlackConfiguration()
        case .penguin: return PenguinConfiguration()
        }
    }
}

// MARK: - 2. 配置协议 (Protocol)
protocol PetConfiguration {
    /// 唯一标识
    var petType: PetType { get }
    
    /// 素材命名前缀 (例如 "cat_black")
    /// 用于拼接图片名: "cat_black_walk_01.png"
    var baseName: String { get }
    
    /// 纹理图集名称 (.atlas 文件夹名)
    var textureAtlasName: String { get }
    
    /// 默认渲染大小 (pt)
    var defaultSize: CGSize { get }
    
    /// 行走速度范围 (像素/秒) - 允许随机快慢
    var walkSpeedRange: ClosedRange<CGFloat> { get }
    
    /// AI 允许随机进入的状态列表
    /// (通常只包含 Daily 状态，不包含被风吹、拖拽等被动状态)
    var capableRandomStates: [PetState] { get }
    
    /// 获取状态持续时间
    /// - Parameter state: 目标状态
    /// - Returns: 时间范围 (例如 5...10 秒)
    func durationRange(for state: PetState) -> ClosedRange<TimeInterval>
}

// MARK: - 3. 基础配置类 (Base Class)
//以此类为基类，减少重复代码
class BasePetConfiguration: PetConfiguration {
    let petType: PetType
    let baseName: String
    let textureAtlasName: String
    let defaultSize: CGSize
    let walkSpeedRange: ClosedRange<CGFloat>
    
    init(petType: PetType,
         baseName: String,
         textureAtlasName: String,
         defaultSize: CGSize,
         walkSpeedRange: ClosedRange<CGFloat>) {
        self.petType = petType
        self.baseName = baseName
        self.textureAtlasName = textureAtlasName
        self.defaultSize = defaultSize
        self.walkSpeedRange = walkSpeedRange
    }
    
    // 默认的随机状态池 (子类可覆盖)
    var capableRandomStates: [PetState] {
        return [
            .daily(.idle),
            .daily(.walking),
            .daily(.sitting),
            .daily(.sleeping)
        ]
    }
    
    // 默认的时间配置逻辑
    func durationRange(for state: PetState) -> ClosedRange<TimeInterval> {
        switch state {
        case .daily(let s):
            switch s {
            case .idle:     return 10...20   // 发呆时间
            case .walking:  return 30...50  // 走路时间
            case .sitting:  return 15...30  // 坐着时间
            case .sleeping: return 50...80 // 睡觉时间长一点
            }
            
        case .play(let s):
            switch s {
            case .sliding:  return 3...5
            }
            
        case .system(let s):
            switch s {
            case .highCPU:    return 5...10  // 烦躁动作持续多久
            case .lowBattery: return 10...20 // 虚弱持续多久
            case .focusMode:  return 1500...1500 // 番茄钟通常由外部打断，这里设个极大值
            }
            
        case .environment:
            // 环境状态通常由物理或外部事件结束，这里的 duration 仅作备用
            return 2...5
            
        case .interrupt(let s):
            switch s {
            case .eating:        return 5...8
            case .waterReminder: return 3...3 // 气泡显示时间
            case .hourlyChime:   return 3...3
            }
        }
    }
}

// MARK: - 4. 具体宠物实现

// --- 黑猫配置 ---
final class CatBlackConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .catBlack,
            baseName: "cat_black",           // 对应资源前缀: cat_black_walk-0.png
            textureAtlasName: "CatBlack",    // 对应 Assets.xcassets 里的名字
            defaultSize: CGSize(width: 64, height: 64),
            walkSpeedRange: 30...50          // 猫跑得比较快
        )
    }
    
    // 可以重写随机池，比如这只猫不喜欢睡觉，只喜欢走
    /*
    override var capableRandomStates: [PetState] {
        return [.daily(.walking), .daily(.idle)]
    }
    */
}

// --- 企鹅配置 ---
final class PenguinConfiguration: BasePetConfiguration {
    init() {
        super.init(
            petType: .penguin,
            baseName: "penguin",
            textureAtlasName: "Penguin",
            defaultSize: CGSize(width: 60, height: 60),
            walkSpeedRange: 15...25          // 企鹅走得慢
        )
    }
    
    override var capableRandomStates: [PetState] {
        // 企鹅特有的滑行状态加入随机池
        return [
            .daily(.idle),
            .daily(.walking),
            .play(.sliding) // 企鹅偶尔会自己滑行玩
        ]
    }
    
    override func durationRange(for state: PetState) -> ClosedRange<TimeInterval> {
        // 针对滑行做特殊时长控制
        if case .play(.sliding) = state {
            return 2...4 // 滑行很快结束
        }
        return super.durationRange(for: state)
    }
}
