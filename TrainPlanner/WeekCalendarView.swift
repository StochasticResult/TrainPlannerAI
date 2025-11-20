import SwiftUI

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @State private var currentWeekStart: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] // Localized by formatter ideally, keeping simple for structure
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Year Header
            HStack {
                Text(monthYearString(currentWeekStart))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { moveWeek(by: -1) }) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    }
                    Button(action: { moveWeek(by: 1) }) {
                        Image(systemName: "chevron.right").font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)

            // Days Row
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    let date = date(for: index)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    
                    VStack(spacing: 8) {
                        Text(weekDayString(date))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(isSelected ? .blue : .secondary)
                        
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 36, height: 36)
                                    .matchedGeometryEffect(id: "selectedDay", in: namespace)
                            } else if isToday {
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 36, height: 36)
                            }
                            
                            Text(dayString(date))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                        }
                        Haptics.selection()
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    @Namespace private var namespace
    
    private func moveWeek(by value: Int) {
        if let newStart = calendar.date(byAdding: .weekOfYear, value: value, to: currentWeekStart) {
            withAnimation(.snappy) { currentWeekStart = newStart }
        }
    }
    
    private func date(for index: Int) -> Date {
        // Adjust to start of week (Sunday usually)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)) ?? Date()
        return calendar.date(byAdding: .day, value: index, to: weekStart) ?? Date()
    }
    
    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
    
    private func weekDayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E" // Mon, Tue
        return f.string(from: date).uppercased()
    }
    
    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

