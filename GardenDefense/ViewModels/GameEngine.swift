import Foundation
import SwiftUI

class GameEngine: ObservableObject {
    // MARK: - Published State
    @Published var sun: Int = 50
    @Published var plants: [Plant] = []
    @Published var zombies: [Zombie] = []
    @Published var projectiles: [Projectile] = []
    @Published var sunDrops: [SunDrop] = []
    @Published var isPaused: Bool = false
    @Published var gameOver: Bool = false
    @Published var victory: Bool = false
    @Published var levelProgress: Double = 0.0
    
    // MARK: - Configuration
    let rows = 5
    let cols = 9
    let cellSize: CGFloat = 80 // Assuming logical points, to be scaled by View
    var gridOrigin: CGPoint = .zero // To be set by View
    
    // Internal State
    private var lastUpdate: Date = Date()
    private var zombieSpawnTimer: TimeInterval = 0
    private var sunSpawnTimer: TimeInterval = 0
    private var waveCount: Int = 0
    private let totalWaves = 10
    
    // MARK: - Game Loop
    func update() {
        guard !isPaused, !gameOver, !victory else { return }
        
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        
        // 1. Spawn Zombies
        updateSpawning(deltaTime: deltaTime)
        
        // 2. Plants Action (Search & Shoot)
        updatePlants(now: now)
        
        // 3. Move Projectiles
        updateProjectiles(deltaTime: deltaTime)
        
        // 4. Move Zombies & Eating
        updateZombies(deltaTime: deltaTime, now: now)
        
        // 5. Collisions (Projectile vs Zombie)
        checkCollisions()
        
        // 6. Cleanup
        cleanup()
    }
    
    // MARK: - Logic
    
    private func updateSpawning(deltaTime: TimeInterval) {
        // Natural Sun Generation
        sunSpawnTimer += deltaTime
        if sunSpawnTimer > 8.0 { // Every 8 seconds roughly
            sunSpawnTimer = 0
            spawnSun()
        }
        
        // Zombie Waves
        if levelProgress < 1.0 {
            zombieSpawnTimer += deltaTime
            if zombieSpawnTimer > 5.0 { // Spawn every 5s for demo
                zombieSpawnTimer = 0
                spawnZombie()
                levelProgress += 0.05 // 20 zombies to win?
                if levelProgress >= 1.0 {
                    // Stop spawning, wait for clear
                }
            }
        } else if zombies.isEmpty {
            victory = true
        }
    }
    
    private func spawnSun() {
        // Random falling sun
        let x = CGFloat.random(in: 50...600)
        let y = CGFloat.random(in: 50...400)
        let sunDrop = SunDrop(position: CGPoint(x: x, y: y))
        sunDrops.append(sunDrop)
    }
    
    private func spawnZombie() {
        let row = Int.random(in: 0..<rows)
        let zombie = Zombie(
            type: .basic,
            row: row,
            xPosition: CGFloat(cols * Int(cellSize)) + 50, // Start off-screen right
            health: ZombieType.basic.health
        )
        zombies.append(zombie)
    }
    
    private func updatePlants(now: Date) {
        for index in plants.indices {
            let plant = plants[index]
            
            // Generate periodic sun (Sunflowers)
            if plant.type == .sunflower {
                if now.timeIntervalSince(plant.lastActionDate) >= 10.0 { // 10s cooldown
                     plants[index].lastActionDate = now
                     // Spawn sun at plant position
                     let pos = gridPositionToPoint(plant.position)
                     sunDrops.append(SunDrop(position: pos))
                }
            }
            // Shoot (Peashooters)
            else if plant.type == .peashooter {
                if now.timeIntervalSince(plant.lastActionDate) >= plant.type.attackInterval {
                    // Check if zombie in lane
                    if zombies.contains(where: { $0.row == plant.position.row && $0.xPosition > 0 }) {
                        plants[index].lastActionDate = now
                        spawnProjectile(from: plant)
                    }
                }
            }
        }
    }
    
    private func spawnProjectile(from plant: Plant) {
        let startX = CGFloat(plant.position.col) * cellSize + (cellSize / 2)
        let projectile = Projectile(
            row: plant.position.row,
            xPosition: startX,
            damage: 20
        )
        projectiles.append(projectile)
    }
    
    private func updateProjectiles(deltaTime: TimeInterval) {
        for i in projectiles.indices {
            projectiles[i].xPosition += projectiles[i].speed * CGFloat(deltaTime)
        }
    }
    
    private func updateZombies(deltaTime: TimeInterval, now: Date) {
        for i in zombies.indices {
            // Check for plants in front (Eating)
            let zombieRect = CGRect(x: zombies[i].xPosition, y: CGFloat(zombies[i].row) * cellSize, width: 40, height: 40)
            
            // Find collided plant
            if let plantIndex = plants.firstIndex(where: {
                let plantRect = CGRect(x: CGFloat($0.position.col) * cellSize, y: CGFloat($0.position.row) * cellSize, width: cellSize, height: cellSize)
                return plantRect.intersects(zombieRect)
            }) {
                zombies[i].isEating = true
                if now.timeIntervalSince(zombies[i].lastAttackDate) > 1.0 {
                    zombies[i].lastAttackDate = now
                    plants[plantIndex].health -= zombies[i].type.attackDamage
                    if plants[plantIndex].health <= 0 {
                        plants.remove(at: plantIndex)
                        zombies[i].isEating = false // Resume walking
                    }
                }
            } else {
                zombies[i].isEating = false
                zombies[i].xPosition -= zombies[i].type.speed * CGFloat(deltaTime)
                
                // Check Game Over (Zombie reached left)
                if zombies[i].xPosition < -50 {
                    gameOver = true
                }
            }
        }
    }
    
    private func checkCollisions() {
        // Projectile vs Zombie
        for pIndex in projectiles.indices.reversed() {
            let p = projectiles[pIndex]
            
            if let zIndex = zombies.firstIndex(where: { $0.row == p.row && abs($0.xPosition - p.xPosition) < 30 }) {
                // Hit
                zombies[zIndex].health -= p.damage
                projectiles.remove(at: pIndex)
                
                if zombies[zIndex].health <= 0 {
                    zombies.remove(at: zIndex)
                }
            } else if p.xPosition > 1000 { // Out of bounds
                 projectiles.remove(at: pIndex)
            }
        }
    }
    
    private func cleanup() {
        // Remove entities? Already done inline mostly.
    }
    
    // MARK: - User Interactions
    
    func collectSun(_ sunDrop: SunDrop) {
        if let index = sunDrops.firstIndex(where: { $0.id == sunDrop.id }) {
            sun += sunDrop.value
            sunDrops.remove(at: index)
        }
    }
    
    func canPlacePlant(at grid: GridPosition, type: PlantType) -> Bool {
        // Check cost
        guard sun >= type.cost else { return false }
        // Check occupancy
        guard !plants.contains(where: { $0.position == grid }) else { return false }
        return true
    }
    
    func placePlant(at grid: GridPosition, type: PlantType) {
        if canPlacePlant(at: grid, type: type) {
            sun -= type.cost
            let newPlant = Plant(type: type, position: grid, health: type.health)
            plants.append(newPlant)
        }
    }
    
    // Helpers
    func pointToGrid(_ point: CGPoint) -> GridPosition? {
        let localX = point.x - gridOrigin.x
        let localY = point.y - gridOrigin.y
        
        let c = Int(localX / cellSize)
        let r = Int(localY / cellSize)
        
        if r >= 0 && r < rows && c >= 0 && c < cols {
              return GridPosition(row: r, col: c)
        }
        return nil
    }
    
    func gridPositionToPoint(_ grid: GridPosition) -> CGPoint {
         // Center of cell
         return CGPoint(
            x: CGFloat(grid.col) * cellSize + gridOrigin.x + cellSize/2,
            y: CGFloat(grid.row) * cellSize + gridOrigin.y + cellSize/2
         )
    }
}
