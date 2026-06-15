import SwiftUI

struct ThemePickerView: View {
    @AppStorage(ThemePrefs.theme) private var theme: AppTheme = .default
    @AppStorage(ThemePrefs.hasSelectedTheme) private var hasSelectedTheme = false

    @State private var selected: AppTheme = .default
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Welcome to ClipboardHistory")
                    .font(.title2.bold())
                Text("Pick a theme. You can change it later in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                ForEach(AppTheme.allCases) { option in
                    card(for: option)
                }
            }

            Button {
                theme = selected
                hasSelectedTheme = true
                onDone()
            } label: {
                Text("Continue")
                    .frame(minWidth: 120)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(36)
        .frame(width: 540, height: 460)
        .onAppear {
            selected = theme
        }
    }

    private func card(for option: AppTheme) -> some View {
        Button {
            selected = option
        } label: {
            VStack(spacing: 10) {
                preview(for: option)
                    .frame(width: 200, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                selected == option ? Color.accentColor : Color.gray.opacity(0.3),
                                lineWidth: selected == option ? 3 : 1
                            )
                    )
                Text(option.displayName)
                    .font(.system(size: 14, weight: selected == option ? .semibold : .regular))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func preview(for option: AppTheme) -> some View {
        ZStack {
            switch option {
            case .default:
                Rectangle().fill(.regularMaterial)
            case .jewish:
                Color.white
                Text("\u{2721}")
                    .font(.system(size: 110))
                    .foregroundStyle(Color(red: 0, green: 0.36, blue: 0.90).opacity(0.20))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Clipboard History")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(option == .jewish ? .black : .primary)
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Rectangle().fill(.gray.opacity(0.2)).frame(height: 1)
                ForEach(0..<6) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.gray.opacity(0.18))
                        .frame(height: 14)
                }
                Spacer()
            }
            .padding(10)
        }
    }
}
