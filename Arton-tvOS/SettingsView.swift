import SwiftUI
import ArtonCore

/// Settings view for adjusting display settings on tvOS
/// Allows users to configure canvas color and padding for artwork display
struct SettingsView: View {
    @StateObject private var settingsManager = DisplaySettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Canvas settings section
                Section {
                    // Canvas color picker
                    Picker("Background Color", selection: canvasColorBinding) {
                        ForEach(CanvasColor.allCases, id: \.self) { color in
                            Text(color.displayName)
                                .tag(color)
                        }
                    }

                    // Canvas padding picker
                    Picker("Canvas Padding", selection: canvasPaddingBinding) {
                        ForEach(DisplaySettings.paddingPresets, id: \.value) { preset in
                            Text(preset.name)
                                .tag(preset.value)
                        }
                    }
                } header: {
                    Text("Canvas")
                } footer: {
                    Text("These settings control how artwork is displayed on screen.")
                }

                // Preview section
                Section {
                    canvasPreview
                        .frame(height: 300)
                        .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
                } header: {
                    Text("Preview")
                }

                // Current settings summary
                Section {
                    currentSettingsSummary
                } header: {
                    Text("Current Settings")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await settingsManager.loadSettings()
            }
        }
    }

    // MARK: - Bindings

    /// Binding for canvas color that saves immediately on change
    private var canvasColorBinding: Binding<CanvasColor> {
        Binding(
            get: { settingsManager.settings.canvasColor },
            set: { newColor in
                Task {
                    await settingsManager.setCanvasColor(newColor)
                }
            }
        )
    }

    /// Binding for canvas padding that saves immediately on change
    private var canvasPaddingBinding: Binding<Double> {
        Binding(
            get: { settingsManager.settings.canvasPadding },
            set: { newPadding in
                Task {
                    await settingsManager.setCanvasPadding(newPadding)
                }
            }
        )
    }

    // MARK: - Canvas Preview

    /// Visual preview of the current canvas settings
    private var canvasPreview: some View {
        GeometryReader { geometry in
            let padding = settingsManager.settings.canvasPadding
            let paddingAmount = min(geometry.size.width, geometry.size.height) * padding

            ZStack {
                // Canvas background color
                canvasBackgroundColor
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Simulated artwork area (with padding applied)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.6))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.artframe")
                                .font(.system(size: 40))
                            Text("Artwork")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    )
                    .padding(paddingAmount)
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    /// Returns the appropriate color for the canvas background
    private var canvasBackgroundColor: Color {
        switch settingsManager.settings.canvasColor {
        case .black:
            return .black
        case .eggshell:
            return Color(red: 0.94, green: 0.92, blue: 0.87)
        }
    }

    // MARK: - Settings Summary

    /// Summary of current settings displayed as text
    private var currentSettingsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Background:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(settingsManager.settings.canvasColor.displayName)
                    .fontWeight(.medium)
            }

            HStack {
                Text("Padding:")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currentPaddingName)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 8)
    }

    /// Gets the display name for the current padding value
    private var currentPaddingName: String {
        let currentPadding = settingsManager.settings.canvasPadding
        if let preset = DisplaySettings.paddingPresets.first(where: { $0.value == currentPadding }) {
            return preset.name
        }
        return "\(Int(currentPadding * 100))%"
    }
}

// MARK: - Preview

#Preview("Settings View") {
    SettingsView()
}

#Preview("Settings View - Eggshell") {
    SettingsView()
}
