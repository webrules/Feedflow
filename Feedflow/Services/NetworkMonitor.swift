import Foundation
import Combine
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isWiFi = false
    @Published var isConnected = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                #if targetEnvironment(simulator)
                // Simulator doesn't report WiFi correctly; treat any connection as WiFi
                self?.isWiFi = path.status == .satisfied
                #else
                self?.isWiFi = path.usesInterfaceType(.wifi)
                #endif
            }
        }
        monitor.start(queue: queue)
    }
}
