import SwiftUI

// MARK: - Loading State View

/// Reusable loading state view
public struct LoadingStateView: View {
    let message: String

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Galleries View

/// Empty state view when no galleries exist
public struct EmptyGalleriesView: View {
    let onCreateGallery: () -> Void

    public init(onCreateGallery: @escaping () -> Void) {
        self.onCreateGallery = onCreateGallery
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Galleries")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a gallery to start curating\nyour art collection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onCreateGallery()
            } label: {
                Label("Create Gallery", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Images View

/// Empty state view when gallery has no images
public struct EmptyImagesView: View {
    let onAddPhotos: () -> Void

    public init(onAddPhotos: @escaping () -> Void) {
        self.onAddPhotos = onAddPhotos
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Images")
                .font(.title2)
                .fontWeight(.medium)

            Text("Add photos to your gallery\nto get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAddPhotos()
            } label: {
                Label("Add Photos", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

/// Reusable error state view
public struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    public init(
        title: String = "Error",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let retryAction = retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Loading State") {
    LoadingStateView(message: "Loading galleries...")
}

#Preview("Empty Galleries") {
    EmptyGalleriesView {
        print("Create gallery tapped")
    }
}

#Preview("Empty Images") {
    EmptyImagesView {
        print("Add photos tapped")
    }
}

#Preview("Error State") {
    ErrorStateView(
        title: "Connection Error",
        message: "Unable to connect to iCloud. Please check your internet connection."
    ) {
        print("Retry tapped")
    }
}
