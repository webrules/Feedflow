import SwiftUI

struct MenuView: View {
    @State private var navigateToGame = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background (Simulated)
                Color.gray.opacity(0.2).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("GARDEN\nDEFENSE")
                        .font(.system(size: 60, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.green)
                        .shadow(color: .black, radius: 2, x: 2, y: 2)
                    
                    Text("MOBILE EDITION")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color.gray)
                        .cornerRadius(5)
                    
                    Spacer()
                    
                    // Wooden Board Buttons
                    VStack(spacing: 15) {
                        MenuButton(title: "ADVENTURE") {
                            navigateToGame = true
                        }
                        MenuButton(title: "MINI-GAMES") {}
                        MenuButton(title: "PUZZLE") {}
                        MenuButton(title: "SURVIVAL") {}
                    }
                    .padding(30)
                    .background(Color.brown)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    
                    Spacer()
                    
                    HStack {
                        VStack {
                            Image(systemName: "book.closed.fill")
                            Text("Almanac")
                        }
                        Spacer()
                        VStack {
                            Image(systemName: "cart.fill")
                            Text("Shop")
                        }
                    }
                    .padding()
                    .font(.caption)
                    .foregroundColor(.white)
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
    }
}
