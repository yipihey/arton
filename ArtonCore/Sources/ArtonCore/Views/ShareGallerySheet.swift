import SwiftUI

/// Sheet for sharing a gallery to CloudKit
#if os(iOS) || os(macOS)
public struct ShareGallerySheet: View {
    let gallery: Gallery
    let images: [ArtworkImage]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharingService = CloudKitSharingService.shared
    @StateObject private var moderationService = ContentModerationService.shared

    @State private var description: String = ""
    @State private var isPublic: Bool = true
    @State private var isUploading = false
    @State private var isScreening = false
    @State private var uploadProgress: Double = 0
    @State private var uploadStatus: String = ""
    @State private var errorMessage: String?
    @State private var sharedGallery: SharedGallery?
    @State private var showCopiedToast = false
    @State private var sensitiveImageIndices: [Int] = []
    @State private var showSensitiveContentWarning = false
    @State private var imagesToUpload: [ArtworkImage] = []

    public init(gallery: Gallery, images: [ArtworkImage]) {
        self.gallery = gallery
        self.images = images
    }

    public var body: some View {
        NavigationStack {
            Form {
                galleryInfoSection
                visibilitySection

                if isScreening {
                    screeningSection
                }

                if showSensitiveContentWarning && !sensitiveImageIndices.isEmpty {
                    sensitiveContentWarningSection
                }

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
                            startSharing()
                        }
                        .disabled(isUploading || isScreening || images.isEmpty)
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

    private var screeningSection: some View {
        Section {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)

                Text("Checking images for sensitive content...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Content Review")
        }
    }

    private var sensitiveContentWarningSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(sensitiveImageIndices.count) image\(sensitiveImageIndices.count == 1 ? "" : "s") may contain sensitive content")
                        .fontWeight(.medium)

                    Text("These images will be excluded from the shared gallery to comply with community guidelines.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Text("Images to upload")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(imagesToUpload.count) of \(images.count)")
            }

            Button("Continue with \(imagesToUpload.count) images") {
                uploadGalleryWithFilteredImages()
            }
            .disabled(imagesToUpload.isEmpty)

            Button("Cancel", role: .cancel) {
                showSensitiveContentWarning = false
                sensitiveImageIndices = []
                imagesToUpload = []
            }
        } header: {
            Text("Sensitive Content Detected")
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

    private func startSharing() {
        // Reset state
        errorMessage = nil
        sensitiveImageIndices = []
        showSensitiveContentWarning = false
        imagesToUpload = images

        // Check if content analysis is available
        if #available(iOS 17.0, macOS 14.0, *) {
            if moderationService.isContentAnalysisAvailable {
                screenImages()
                return
            }
        }

        // If content analysis not available, upload directly
        uploadGallery()
    }

    private func screenImages() {
        isScreening = true

        Task {
            if #available(iOS 17.0, macOS 14.0, *) {
                // Load images and analyze them
                var flaggedIndices: [Int] = []

                for (index, artworkImage) in images.enumerated() {
                    if let data = try? Data(contentsOf: artworkImage.fileURL),
                       let platformImg = loadPlatformImage(from: data) {
                        let result = await moderationService.analyzeImage(platformImg)
                        if result.isSensitive {
                            flaggedIndices.append(index)
                        }
                    }
                }

                sensitiveImageIndices = flaggedIndices
                isScreening = false

                if flaggedIndices.isEmpty {
                    // No sensitive content found - proceed with upload
                    uploadGallery()
                } else {
                    // Sensitive content found - show warning and filter images
                    imagesToUpload = images.enumerated()
                        .filter { !flaggedIndices.contains($0.offset) }
                        .map { $0.element }
                    showSensitiveContentWarning = true
                }
            } else {
                isScreening = false
                uploadGallery()
            }
        }
    }

    private func uploadGalleryWithFilteredImages() {
        showSensitiveContentWarning = false
        performUpload(with: imagesToUpload)
    }

    private func uploadGallery() {
        performUpload(with: images)
    }

    private func performUpload(with imagesToShare: [ArtworkImage]) {
        guard !imagesToShare.isEmpty else {
            errorMessage = "No images to upload after content filtering."
            return
        }

        isUploading = true
        errorMessage = nil
        uploadProgress = 0
        uploadStatus = "Preparing..."

        Task {
            do {
                let shared = try await sharingService.shareGallery(
                    gallery,
                    images: imagesToShare,
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

    private func loadPlatformImage(from data: Data) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
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
