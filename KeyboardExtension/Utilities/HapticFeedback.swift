import SwiftUI

struct HapticFeedback {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    
    static func playLight() {
        light.prepare()
        light.impactOccurred()
    }
    
    static func playMedium() {
        medium.prepare()
        medium.impactOccurred()
    }
}
