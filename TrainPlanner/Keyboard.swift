import Foundation
import SwiftUI
import Combine
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: &self.$currentHeight)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
