import SwiftUI

/// Sheet for sharing a gallery to CloudKit
#if os(iOS) || os(macOS)
public struct ShareGallerySheet: View {
    let gallery: Gallery
    let images: [ArtworkImage]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharingService = CloudKitSharingService.shared

    @State private var description: String = ""
    @State private var isPublic: Bool = true
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var uploadStatus: String = ""
    @State private var errorMessage: String?
    @State private var sharedGallery: SharedGallery?
    @State private var showCopiedToast = false

    public init(gallery: Gallery, images: [ArtworkImage]) {
        self.gallery = gallery
        self.images = images
    }

    public var body: some View {
        NavigationStack {
            Form {
                galleryInfoSection
                visibilitySection

                if isUploading {
                    uploadingSection
                }

                if let error = errorMessage {
                    errorSection(error)
                }

                if let shared = sharedGallery {
                    successSection(shared)
                }
            }
            .navigationTitle("Share Gallery")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }

                if sharedGallery == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Share") {
                            uploadGallery()
                        }
                        .disabled(isUploading || images.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isUploading)
        }
    }

    // MARK: - Sections

    private var galleryInfoSection: some View {
        Section {
            HStack {
                Text("Name")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(gallery.name)
            }

            HStack {
                Text("Images")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(images.count)")
            }

            TextField("Description (optional)", text: $description, axis: .vertical)
                .lineLimit(3...6)
                .disabled(isUploading || sharedGallery != nil)
        } header: {
            Text("Gallery Info")
        }
    }

    private var visibilitySection: some View {
        Section {
            Toggle("Show in Explore", isOn: $isPublic)
                .disabled(isUploading || sharedGallery != nil)

            if isPublic {
                Label {
                    Text("Anyone using Arton can discover and view this gallery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.blue)
                }
            } else {
                Label {
                    Text("Only people with the link can view this gallery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "link")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Visibility")
        }
    }

    private var uploadingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(.linear)

                Text(uploadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(uploadProgress * 100))% complete")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Uploading")
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
                uploadGallery()
            }
        } header: {
            Text("Error")
        }
    }

    private func successSection(_ shared: SharedGallery) -> some View {
        Section {
            Label {
                Text("Gallery shared successfully!")
                    .foregroundStyle(.green)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            // Share link button
            ShareLink(item: shared.shareURL) {
                Label("Share Link", systemImage: "square.and.arrow.up")
            }

            // Copy link button
            Button {
                copyLinkToClipboard(shared.shareURL)
            } label: {
                Label(showCopiedToast ? "Copied!" : "Copy Link", systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
            }

            // Preview link
            HStack {
                Text("Link")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(shared.shareURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } header: {
            Text("Shared!")
        }
    }

    // MARK: - Actions

    private func uploadGallery() {
        isUploading = true
        errorMessage = nil
        uploadProgress = 0
        uploadStatus = "Preparing..."

        Task {
            do {
                let shared = try await sharingService.shareGallery(
                    gallery,
                    images: images,
                    description: description.isEmpty ? nil : description,
                    isPublic: isPublic
                ) { progress, status in
                    Task { @MainActor in
                        self.uploadProgress = progress
                        self.uploadStatus = status
                    }
                }

                sharedGallery = shared
                isUploading = false

            } catch {
                errorMessage = error.localizedDescription
                isUploading = false
            }
        }
    }

    private func copyLinkToClipboard(_ url: URL) {
        #if os(iOS)
        UIPasteboard.general.string = url.absoluteString
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif

        withAnimation {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}
#endif
