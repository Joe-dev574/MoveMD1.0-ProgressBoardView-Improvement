import SwiftUI
import SwiftData

struct PersonalInfoSectionView: View {
    @Bindable var user: User // Use @Bindable for direct mutation
    var themeColor: Color

    var body: some View {
        Section {
            TextField("Name", text: Binding(
                get: { user.name ?? "" },
                set: { user.name = $0.isEmpty ? nil : $0 }
            ))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .textInputAutocapitalization(.words)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("nameField")
        } header: {
            Text("Personal Info")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(themeColor)
        }
    }
}
