import SwiftUI

struct HapticFeedback {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let medium = UIImpactFeedbackGenerator(style: .medium)
    static let soft = UIImpactFeedbackGenerator(style: .soft)
    static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    
    static func playLight() {
        light.prepare()
        light.impactOccurred()
    }
    
    static func playMedium() {
        medium.prepare()
        medium.impactOccurred()
    }

    static func playSoft() {
        soft.prepare()
        soft.impactOccurred()
    }

    static func playRigid() {
        rigid.prepare()
        rigid.impactOccurred()
    }
}
