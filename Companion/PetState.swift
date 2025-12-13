import SpriteKit

// MARK: - 状态定义
enum PetState: Equatable {
    // 基础生活 (低优先级)
    case daily(DailyState)
    // 互动玩耍 (中优先级)
    case play(PlayState)
    // 系统状态 (高优先级 - 很有用)
    case system(SystemState)
    // 环境/不可控状态 (最高强制力)
    case environment(EnvironmentState)
    // 临时打断 (最高优先级 - 提醒)
    case interrupt(InterruptState)
    
    // --- 子状态 ---
    enum DailyState: String, Equatable {
        case idle, walking, sitting, sleeping, eating
    }
    
    enum PlayState: String, Equatable {
        case sliding
        // 未来可以加: case ballChasing
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
    
    // MARK: - 核心逻辑属性 (这是状态机的灵魂)
    
    /// 优先级：决定谁能打断谁
    var priority: Int {
        switch self {
        case .daily: return 0          // 随时可以被打断
        case .play: return 10          // 玩耍中不容易被打断，除非系统事件
        case .system: return 50        // 专注模式/高CPU，不应被闲逛打断
        case .environment: return 80   // 风吹/拖拽，物理强制力
        case .interrupt: return 100    // 喝水/报时，必须立即执行
        }
    }
    
    /// 是否可交互 (鼠标是否能点)
    var canInteract: Bool {
        switch self {
        case .environment(let s):
            // 风吹时不可点击，挂住时可以点击解救，拖拽时肯定算交互中
            switch s {
            case .blownByWind: return false
            case .stuckOnEdge: return true
            default: return true
            }
        case .interrupt: return false
        default: return true
        }
    }
    
    /// 动画是否循环
    var isLooping: Bool {
        switch self {
        
        // 改为下面这样：
        case .interrupt(let s):
            // 吃饭动作不循环（吃完就睡），但报时建议循环（一直看着你直到时间到）
            switch s {
            case .hourlyChime:
                return true
            case .waterReminder:
                return false
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
            case .highCPU: return .angry // 复用 angry 动画作为烦躁
            case .lowBattery: return .sleep // 复用 sleep 或做新动画
            case .focusMode: return .front  // 复用 front 或做看书动画
            }
        case .environment(let s):
            switch s {
            case .falling, .beingDragged: return .drag
            case .blownByWind: return .drag // 风吹可以用 drag 动作（看起来像被拎起来）
            case .stuckOnEdge: return .drag // 挂在墙上也可以用 drag，或者专门的 hanging
            }
        case .interrupt(let s):
            switch s {
            case .waterReminder, .hourlyChime: return .front // 配合气泡
            }
        }
    }
}

// 对应更新 PetAnimation
enum PetAnimation: String, CaseIterable {
    case walk, idle, eat, drag, sleep, angry, front, slide
    // 如果有资源，可以在这里加 case reading, case fanning
    
    var animationKey: String { "\(self.rawValue)_animation" }
}
