//
//  PetState.swift
//  Companion
//
//  Created by it on 2025/12/10.
//
import SpriteKit

enum PetState: Equatable {
    case daily(DailyState)
    case interrupt(InterruptState)
    case nonInteractive(NonInteractiveState)
    case play(PlayState)
    
    // MARK: - 子状态枚举
    enum DailyState: String, Equatable {
        case walking
        case idle
        case sitting
        case sleeping
    }
    
    enum InterruptState: String, Equatable {
        case eating
    }
    
    enum NonInteractiveState: String, Equatable {
        case falling
        case beingDragged
    }
    
    enum PlayState: String, Equatable {
        case sliding
    }
    
    // MARK: - 实用属性
    var categoryName: String {
        switch self {
        case .daily: return "daily"
        case .interrupt: return "interrupt"
        case .nonInteractive: return "nonInteractive"
        case .play: return "play"
        }
    }
    
    var animation: PetAnimation {
        switch self {
        case .daily(let state):
            switch state {
            case .walking: return .walk
            case .idle: return .idle
            case .sitting: return .front
            case .sleeping: return .sleep
            }
        case .interrupt(let state):
            switch state {
            case .eating: return .eat
            }
        case .nonInteractive(let state):
            switch state {
            case .falling, .beingDragged: return .drag
            }
        case .play(let state):
            switch state {
            case .sliding: return .slide
            }
        }
    }
    
    var canInteract: Bool {
        switch self {
        case .nonInteractive: return false
        case .interrupt: return false
        default: return true
        }
    }
    
    var canAutoTransition: Bool {
        if case .daily = self {
            return true
        }
        return false
    }
    
    // 实现Equatable所需的静态方法
    static func == (lhs: PetState, rhs: PetState) -> Bool {
        switch (lhs, rhs) {
        case (.daily(let lhsDaily), .daily(let rhsDaily)):
            return lhsDaily == rhsDaily
        case (.interrupt(let lhsInterrupt), .interrupt(let rhsInterrupt)):
            return lhsInterrupt == rhsInterrupt
        case (.nonInteractive(let lhsNonInteractive), .nonInteractive(let rhsNonInteractive)):
            return lhsNonInteractive == rhsNonInteractive
        case (.play(let lhsPlay), .play(let rhsPlay)):
            return lhsPlay == rhsPlay
        default:
            return false
        }
    }
}

// MARK: - 动画枚举（保持不变）
enum PetAnimation: String, CaseIterable {
    case walk
    case idle
    case eat
    case drag
    case sleep
    case angry
    case front
    case slide
    
    var animationKey: String {
        return "\(self.rawValue)_animation"
    }
}
