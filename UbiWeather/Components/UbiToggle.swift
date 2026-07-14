import SwiftUI

/// Matches the reference's `toggle(on, fn)` pill switch (46x28 track, 22pt thumb).
struct UbiToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() }
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .fill(isOn ? UbiColors.toggleOn : UbiColors.toggleOffTrack)
                .frame(width: 46, height: 28)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        .padding(3),
                    alignment: isOn ? .trailing : .leading
                )
        }
        .buttonStyle(.plain)
    }
}
