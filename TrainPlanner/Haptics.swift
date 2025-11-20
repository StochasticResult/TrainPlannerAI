import UIKit

enum Haptics {
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare(); g.impactOccurred()
    }
    static func heavy() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare(); g.impactOccurred()
    }
    static func success() {
        let n = UINotificationFeedbackGenerator()
        n.prepare(); n.notificationOccurred(.success)
    }
    static func warning() {
        let n = UINotificationFeedbackGenerator()
        n.prepare(); n.notificationOccurred(.warning)
    }
    static func error() {
        let n = UINotificationFeedbackGenerator()
        n.prepare(); n.notificationOccurred(.error)
    }
    static func selection() {
        let g = UISelectionFeedbackGenerator()
        g.prepare(); g.selectionChanged()
    }
}


