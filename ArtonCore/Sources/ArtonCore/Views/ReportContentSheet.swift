import SwiftUI

/// Sheet for reporting inappropriate content
public struct ReportContentSheet: View {
    let galleryID: String
    let galleryName: String
    let ownerName: String
    let imageID: String?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var moderationService = ContentModerationService.shared

    @State private var selectedReason: ReportReason = .inappropriate
    @State private var additionalDetails: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isSubmitted = false

    public init(
        galleryID: String,
        galleryName: String,
        ownerName: String,
        imageID: String? = nil
    ) {
        self.galleryID = galleryID
        self.galleryName = galleryName
        self.ownerName = ownerName
        self.imageID = imageID
    }

    public var body: some View {
        NavigationStack {
            Form {
                contentSection
                reasonSection
                detailsSection

                if let error = errorMessage {
                    errorSection(error)
                }

                if isSubmitted {
                    successSection
                }
            }
            .navigationTitle("Report Content")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSubmitted ? "Close" : "Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                if !isSubmitted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            submitReport()
                        }
                        .disabled(isSubmitting)
                    }
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    // MARK: - Sections

    private var contentSection: some View {
        Section {
            HStack {
                Text(imageID != nil ? "Image in" : "Gallery")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(galleryName)
            }

            HStack {
                Text("Shared by")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(ownerName)
            }
        } header: {
            Text("Content Being Reported")
        }
    }

    private var reasonSection: some View {
        Section {
            Picker("Reason", selection: $selectedReason) {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Text(reason.rawValue).tag(reason)
                }
            }
            .pickerStyle(.menu)
            .disabled(isSubmitting || isSubmitted)
        } header: {
            Text("Reason for Report")
        } footer: {
            Text(reasonDescription(for: selectedReason))
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Additional details (optional)", text: $additionalDetails, axis: .vertical)
                .lineLimit(3...6)
                .disabled(isSubmitting || isSubmitted)
        } header: {
            Text("Additional Information")
        } footer: {
            Text("Please provide any additional context that may help us review this report.")
        }
    }

    private func errorSection(_ error: String) -> some View {
        Section {
            Label {
                Text(error)
                    .foregroundStyle(.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            Button("Try Again") {
                errorMessage = nil
                submitReport()
            }
        }
    }

    private var successSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Report Submitted")
                        .fontWeight(.medium)
                    Text("Thank you for helping keep Arton safe. We'll review this content and take appropriate action.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Helpers

    private func reasonDescription(for reason: ReportReason) -> String {
        switch reason {
        case .inappropriate:
            return "Content that is sexually explicit, violent, or otherwise inappropriate."
        case .copyright:
            return "Content that infringes on your copyright or intellectual property."
        case .spam:
            return "Content that is spam, advertising, or off-topic."
        case .harassment:
            return "Content that harasses, bullies, or targets individuals."
        case .other:
            return "Other concerns not covered by the above categories."
        }
    }

    // MARK: - Actions

    private func submitReport() {
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await moderationService.reportContent(
                    galleryID: galleryID,
                    imageID: imageID,
                    reason: selectedReason,
                    details: additionalDetails.isEmpty ? nil : additionalDetails
                )

                isSubmitted = true
                isSubmitting = false

            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

#Preview {
    ReportContentSheet(
        galleryID: "test-gallery",
        galleryName: "Beautiful Landscapes",
        ownerName: "John Doe"
    )
}
