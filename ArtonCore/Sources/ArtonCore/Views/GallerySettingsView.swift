import SwiftUI

/// A settings editor view for configuring gallery display options
/// Works on iOS, tvOS, and macOS
public struct GallerySettingsView: View {
    @Binding var settings: GallerySettings
    let galleryName: String
    var onSave: (() -> Void)? = nil

    public init(settings: Binding<GallerySettings>, galleryName: String, onSave: (() -> Void)? = nil) {
        self._settings = settings
        self.galleryName = galleryName
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            displayOrderSection
            transitionsSection
            timingSection
        }
        .navigationTitle(galleryName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Display Order Section

    private var displayOrderSection: some View {
        Section {
            Picker(selection: $settings.displayOrder) {
                ForEach(DisplayOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            } label: {
                Label("Order", systemImage: "arrow.up.arrow.down")
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.menu)
            #endif
            .onChange(of: settings.displayOrder) { _, _ in
                onSave?()
            }
        } header: {
            Label("Display Order", systemImage: "list.number")
                .textCase(nil)
        } footer: {
            Text(displayOrderDescription)
        }
    }

    private var displayOrderDescription: String {
        switch settings.displayOrder {
        case .serial:
            return "Images are shown in alphabetical order by filename."
        case .random:
            return "Images are shuffled and shown in random order."
        case .pingPong:
            return "Images play forward then backward continuously."
        }
    }

    // MARK: - Transitions Section

    private var transitionsSection: some View {
        Section {
            Picker(selection: $settings.transitionEffect) {
                ForEach(TransitionEffect.allCases, id: \.self) { effect in
                    Text(effect.displayName).tag(effect)
                }
            } label: {
                Label("Effect", systemImage: "wand.and.stars")
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.menu)
            #endif
            .onChange(of: settings.transitionEffect) { _, _ in
                onSave?()
            }

            if settings.transitionEffect != .none {
                transitionDurationRow
            }
        } header: {
            Label("Transitions", systemImage: "sparkles.rectangle.stack")
                .textCase(nil)
        }
    }

    private var transitionDurationRow: some View {
        HStack {
            Label("Duration", systemImage: "timer")

            Spacer()

            #if os(tvOS)
            // tvOS: Use simple text display with stepper-like behavior
            Text(formattedDuration(settings.effectiveTransitionDuration))
                .foregroundStyle(.secondary)
            #else
            // iOS/macOS: Use a slider for fine control
            Slider(
                value: Binding(
                    get: { settings.transitionDuration ?? settings.transitionEffect.defaultDuration },
                    set: { settings.transitionDuration = $0 }
                ),
                in: 0.25...3.0,
                step: 0.25
            ) {
                Text("Duration")
            } minimumValueLabel: {
                Text("0.25s")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("3s")
                    .font(.caption2)
            }
            .frame(maxWidth: 200)
            .onChange(of: settings.transitionDuration) { _, _ in
                onSave?()
            }

            Text(formattedDuration(settings.effectiveTransitionDuration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            #endif
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2fs", duration)
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        Section {
            Picker(selection: $settings.displayInterval) {
                ForEach(GallerySettings.intervalPresets, id: \.seconds) { preset in
                    Text(preset.name).tag(preset.seconds)
                }
            } label: {
                Label("Display Time", systemImage: "clock")
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.menu)
            #endif
            .onChange(of: settings.displayInterval) { _, _ in
                onSave?()
            }
        } header: {
            Label("Timing", systemImage: "hourglass")
                .textCase(nil)
        } footer: {
            Text("How long each image is displayed before transitioning to the next.")
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Gallery Settings") {
    NavigationStack {
        GallerySettingsView(
            settings: .constant(GallerySettings()),
            galleryName: "My Art Collection"
        )
    }
}

#Preview("Gallery Settings - Random Order") {
    NavigationStack {
        GallerySettingsView(
            settings: .constant(GallerySettings(
                displayOrder: .random,
                transitionEffect: .slide,
                displayInterval: 60
            )),
            galleryName: "Photography"
        )
    }
}
#endif
