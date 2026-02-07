# Garden Defense (iPad Prototype)

A SwiftUI implementation of a lane-defense game inspired by *Plants vs. Zombies*, designed for iPad.

## Overview

This project reproduces the core gameplay mechanics of Level 1-1 as requested:
- **Sun Economy**: Collect falling sun and sun produced by Sunflowers.
- **Planting**: Drag/Select plants from the sidebar to place them on the grid.
- **Defense**: Peashooters shoot projectiles at incoming Zombies.
- **Enemies**: Zombies spawn and march towards the house (left side).
- **Win/Loss**: Survive the wave using your plants.

## Structure

- **App Entry**: `GardenDefenseApp.swift`
- **Logic**: `ViewModels/GameEngine.swift` - Handles the game loop, collisions, and state.
- **Data**: `Models/GameModels.swift` - Structs for Plants, Zombies, and constants.
- **UI**:
  - `Views/MenuView.swift`: Main Title Screen.
  - `Views/GameView.swift`: The gameplay board.

## How to Run

1. Open Xcode.
2. Create a new **iOS App** project named "GardenDefense".
3. Select **SwiftUI** as the interface.
4. Replace the default files with the contents of this folder.
   - Ensure `GardenDefenseApp.swift` is your `@main` entry point.
   - Add the `Models`, `ViewModels`, and `Views` folders to the project group.
5. Run on an **iPad Simulator** (e.g., iPad Pro 12.9").

## Controls

- **Tap Sun**: Collect sun.
- **Select Plant**: Tap a seed packet in the sidebar (if you have enough sun).
- **Place Plant**: Tap an empty green grid cell.
- **Pause**: Tap the pause button in the top right.

## Customization

The game logic is tunable in `GameEngine.swift` (spawn rates, health, damage).
