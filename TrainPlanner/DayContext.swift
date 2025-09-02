import Foundation

final class DayContext: ObservableObject {
    @Published var date: Date = Calendar.current.startOfDay(for: Date())
}


