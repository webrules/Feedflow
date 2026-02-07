import Foundation
import SwiftUI

// MARK: - Enums & Types

enum PlantType: String, CaseIterable, Identifiable {
    case peashooter
    case sunflower
    case wallnut
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .peashooter: return "Peashooter"
        case .sunflower: return "Sunflower"
        case .wallnut: return "Wall-nut"
        }
    }
    
    var cost: Int {
        switch self {
        case .peashooter: return 100
        case .sunflower: return 50
        case .wallnut: return 50
        }
    }
    
    var health: Int {
        switch self {
        case .peashooter: return 100
        case .sunflower: return 100
        case .wallnut: return 1000
        }
    }
    
    var cooldown: TimeInterval {
        switch self {
        case .peashooter: return 2.0
        case .sunflower: return 5.0
        case .wallnut: return 10.0
        }
    }
    
    var attackInterval: TimeInterval { // For shooting plants
        switch self {
        case .peashooter: return 1.5
        default: return 0
        }
    }
}

enum ZombieType: String {
    case basic
    
    var health: Int {
        switch self {
        case .basic: return 200
        }
    }
    
    var speed: CGFloat { // Points per second
        switch self {
        case .basic: return 15.0
        }
    }
    
    var attackDamage: Int {
        return 20 // Damage per second
    }
}

struct GridPosition: Hashable, Equatable {
    let row: Int
    let col: Int
}

// MARK: - Game Entities

struct Plant: Identifiable {
    let id = UUID()
    let type: PlantType
    let position: GridPosition
    var health: Int
    var lastActionDate: Date = Date()
}

struct Zombie: Identifiable {
    let id = UUID()
    let type: ZombieType
    let row: Int
    var xPosition: CGFloat // Horizontal position (0 to ScreenWidth)
    var health: Int
    var isEating: Bool = false
    var lastAttackDate: Date = Date()
}

struct Projectile: Identifiable {
    let id = UUID()
    let row: Int
    var xPosition: CGFloat
    let damage: Int
    let speed: CGFloat = 250 // Fast
}

struct SunDrop: Identifiable {
    let id = UUID()
    var position: CGPoint
    let value: Int = 25
    var createdAt: Date = Date()
}
