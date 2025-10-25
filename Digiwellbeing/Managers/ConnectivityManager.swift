//
//  ConnectivityManager.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 18/09/25.
//

import Foundation
import WatchConnectivity
internal import Combine


struct HeartRateMessage: Equatable {
    let heartRate: Double
    let timestamp: TimeInterval
    
    init?(from dictionary: [String: Any]) {
        guard let heartRate = dictionary["heartRate"] as? Double,
              let timestamp = dictionary["timestamp"] as? TimeInterval else {
            return nil
        }
        self.heartRate = heartRate
        self.timestamp = timestamp
    }
    
    static func == (lhs: HeartRateMessage, rhs: HeartRateMessage) -> Bool {
        return lhs.heartRate == rhs.heartRate && lhs.timestamp == rhs.timestamp
    }
}


final class ConnectivityManager: NSObject, ObservableObject {
    static let shared = ConnectivityManager()
    
    @Published var heartRateData: [String: Any] = [:]
    @Published var isReachable: Bool = false
    @Published var dataUpdateTrigger: UUID = UUID()
    
    private override init() {
        super.init()
        
        #if !os(watchOS)
        guard WCSession.isSupported() else { return }
        #endif
        
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            DispatchQueue.main.async {
                self.heartRateData = message
                self.dataUpdateTrigger = UUID() // Trigger the change
            }
        }
    }

    
    func sendHeartRateData(_ heartRate: Double) {
        guard WCSession.default.isReachable else { return }
        
        let message = [
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send heart rate data: \(error.localizedDescription)")
        }
    }


extension ConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
