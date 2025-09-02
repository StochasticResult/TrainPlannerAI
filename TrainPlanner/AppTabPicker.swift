import SwiftUI

/// A shared segmented picker to switch between plan and nutrition modes.
struct AppTabPicker: View {
    @Binding var selected: AppTab

    var body: some View {
        Picker("", selection: $selected) {
            ForEach(AppTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }
}

