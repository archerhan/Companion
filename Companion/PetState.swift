import Foundation

// MARK: - 状态定义
enum PetState: Equatable {
    // 基础生活 (低优先级: 0)
    case daily(DailyState)
    // 互动玩耍 (中优先级: 10)
    case play(PlayState)
    // 系统状态 (高优先级: 50)
    case system(SystemState)
    // 环境/不可控状态 (最高强制力: 80)
    case environment(EnvironmentState)
    // 临时打断 (较高优先级: 70 - 能打断专注，但不能打断风吹)
    case interrupt(InterruptState)
    
    // --- 子状态 ---
    enum DailyState: String, Equatable {
        case idle, walking, sitting, sleeping, eating
    }
    
    enum PlayState: String, Equatable {
        case sliding
    }
    
    enum SystemState: String, Equatable {
        case highCPU      // 烦躁/扇风
        case lowBattery   // 虚弱/爬行
        case focusMode    // 专注/看书
    }
    
    enum EnvironmentState: String, Equatable {
        case falling        // 下落
        case beingDragged   // 拖拽
        case blownByWind    // 被风吹
        case stuckOnEdge    // 挂在边缘
    }
    
    enum InterruptState: String, Equatable {
        case waterReminder  // 喝水提醒
        case hourlyChime    // 报时
    }
    
    // MARK: - 核心属性
    
    /// 优先级：决定谁能打断谁
    var priority: Int {
        switch self {
        case .daily: return 0
        case .play: return 10
        case .system: return 50
        case .interrupt: return 70     // 调整为 70 (低于 Environment)
        case .environment: return 80   // 最高物理强制力
        }
    }
    
    /// 是否可交互 (窗口是否捕获鼠标)
    var canInteract: Bool {
        switch self {
        case .environment(let s):
            switch s {
            case .blownByWind: return false
            case .stuckOnEdge: return true
            default: return true
            }
        case .interrupt: return false
        case .system(let s):
            // 【关键】专注模式必须为 true，否则无法触发右键菜单
            if s == .focusMode { return true }
            return true
        default: return true
        }
    }
    
    /// 动画是否循环
    var isLooping: Bool {
        switch self {
        case .interrupt(let s):
            switch s {
            case .hourlyChime: return true
            case .waterReminder: return true // 喝水动画(idle)需要循环
            }
        default: return true
        }
    }
    
    /// 对应的动画 Key
    var animation: PetAnimation {
        switch self {
        case .daily(let s):
            switch s {
            case .walking: return .walk
            case .idle: return .idle
            case .sitting: return .front
            case .sleeping: return .sleep
            case .eating: return .eat
            }
        case .play(let s):
            switch s {
            case .sliding: return .slide
            }
        case .system(let s):
            switch s {
            case .highCPU: return .angry
            case .lowBattery: return .sleep
            case .focusMode: return .front
            }
        case .environment(let s):
            switch s {
            case .falling, .beingDragged, .blownByWind, .stuckOnEdge: return .drag
            }
        case .interrupt(let s):
            switch s {
            case .hourlyChime: return .front
            case .waterReminder: return .idle // 喝水时播放 Idle
            }
        }
    }
}

enum PetAnimation: String, CaseIterable {
    case walk, idle, eat, drag, sleep, angry, front, slide
    var animationKey: String { "\(self.rawValue)_animation" }
}
