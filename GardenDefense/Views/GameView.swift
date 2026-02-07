import SwiftUI

struct GameView: View {
    @StateObject var engine = GameEngine()
    @State private var selectedPlant: PlantType? = nil
    
    // Timer for game loop (60 FPS)
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            Color.green.opacity(0.8).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    // Sun Counter
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                            .font(.title)
                        Text("\(engine.sun)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    // Level Indicator
                    Text("LEVEL 1-1")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(15)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Pause Button
                    Button(action: { engine.isPaused.toggle() }) {
                        Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.cyan.opacity(0.3))
                
                HStack(spacing: 0) {
                    // Side Bar (Plant Selection)
                    VStack {
                        ForEach(PlantType.allCases) { plant in
                            PlantSelectionCard(plant: plant, isSelected: selectedPlant == plant, canAfford: engine.sun >= plant.cost)
                                .onTapGesture {
                                    if engine.sun >= plant.cost {
                                        selectedPlant = plant
                                    }
                                }
                        }
                        Spacer()
                    }
                    .frame(width: 100)
                    .background(Color(red: 0.4, green: 0.2, blue: 0.1)) // Wood color
                    
                    // Game Area
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            
                            // 1. Grid (Lawns)
                            VStack(spacing: 0) {
                                ForEach(0..<engine.rows, id: \.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(0..<engine.cols, id: \.self) { col in
                                            Rectangle()
                                                .fill((row + col) % 2 == 0 ? Color.green : Color.green.opacity(0.8))
                                                .frame(width: engine.cellSize, height: engine.cellSize)
                                                .border(Color.black.opacity(0.1))
                                                .onTapGesture {
                                                    if let plant = selectedPlant {
                                                        engine.placePlant(at: GridPosition(row: row, col: col), type: plant)
                                                        selectedPlant = nil // Deselect after placing
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            // Store origin for logic
                            .onAppear {
                                engine.gridOrigin = .zero // Simplified for this layout (top-left of ZStack)
                            }
                            
                            // 2. Plants
                            ForEach(engine.plants) { plant in
                                PlantView(plant: plant)
                                    .position(
                                        x: CGFloat(plant.position.col) * engine.cellSize + engine.cellSize/2,
                                        y: CGFloat(plant.position.row) * engine.cellSize + engine.cellSize/2
                                    )
                            }
                            
                            // 3. Zombies
                            ForEach(engine.zombies) { zombie in
                                ZombieView(zombie: zombie)
                                    .position(
                                        x: zombie.xPosition,
                                        y: CGFloat(zombie.row) * engine.cellSize + engine.cellSize/2
                                    )
                            }
                            
                            // 4. Projectiles
                            ForEach(engine.projectiles) { proj in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 15, height: 15)
                                    .position(
                                        x: proj.xPosition,
                                        y: CGFloat(proj.row) * engine.cellSize + engine.cellSize/2
                                    )
                            }
                            
                            // 5. Sun Drops
                            ForEach(engine.sunDrops) { sun in
                                SunView()
                                    .position(sun.position)
                                    .onTapGesture {
                                        engine.collectSun(sun)
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.green.opacity(0.6))
                        .clipped()
                    }
                }
            }
            
            // Popups
            if engine.gameOver {
                VStack {
                    Text("THE ZOMBIES ATE YOUR BRAINS!")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Button("Restart") {
                        engine = GameEngine()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
            
            if engine.victory {
                VStack {
                    Text("LEVEL CLEARED!")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Button("Next Level") {
                        // TODO
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
        }
        .onReceive(timer) { _ in
            engine.update()
        }
    }
}

// MARK: - Subviews

struct PlantSelectionCard: View {
    let plant: PlantType
    let isSelected: Bool
    let canAfford: Bool
    
    var body: some View {
        VStack {
            Image(systemName: iconName(for: plant))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundColor(.green)
            
            Text("\(plant.cost)")
                .font(.caption)
                .foregroundColor(.black)
        }
        .frame(width: 70, height: 90)
        .background(canAfford ? Color.white : Color.gray)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 4)
        )
        .opacity(canAfford ? 1.0 : 0.6)
        .padding(5)
    }
    
    func iconName(for type: PlantType) -> String {
        switch type {
        case .peashooter: return "circle.circle.fill" // Looks like mouth
        case .sunflower: return "sun.max.fill"
        case .wallnut: return "shield.fill"
        }
    }
}

struct PlantView: View {
    let plant: Plant
    
    var body: some View {
        ZStack {
            if plant.type == .peashooter {
                Image(systemName: "circle.circle.fill")
                    .resizable()
                    .foregroundColor(.green)
                    .frame(width: 50, height: 50)
            } else if plant.type == .sunflower {
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .foregroundColor(.yellow)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(Date().timeIntervalSince1970 * 50)) // Spin
            } else {
                Image(systemName: "shield.fill")
                    .resizable()
                    .foregroundColor(.brown)
                    .frame(width: 50, height: 60)
            }
        }
    }
}

struct ZombieView: View {
    let zombie: Zombie
    
    var body: some View {
        VStack {
            Image(systemName: "figure.walk")
                .resizable()
                .foregroundColor(.gray)
                .frame(width: 40, height: 60)
                .offset(x: zombie.isEating ? CGFloat(sin(Date().timeIntervalSince1970 * 20) * 5) : 0) // Shake when eating
        }
    }
}

struct SunView: View {
    var body: some View {
        Image(systemName: "sun.max.fill")
            .resizable()
            .foregroundColor(.yellow)
            .shadow(color: .orange, radius: 10)
            .frame(width: 60, height: 60)
            .transition(.scale)
    }
}
