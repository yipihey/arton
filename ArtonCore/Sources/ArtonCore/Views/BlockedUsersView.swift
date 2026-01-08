import SwiftUI

/// View for managing blocked users
public struct BlockedUsersView: View {
    @StateObject private var moderationService = ContentModerationService.shared
    @State private var showingUnblockConfirmation = false
    @State private var userToUnblock: BlockedUser?
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        List {
            if moderationService.blockedUsers.isEmpty && !moderationService.isLoading {
                emptyState
            } else {
                blockedUsersSection
            }

            if let error = errorMessage {
                errorSection(error)
            }
        }
        .navigationTitle("Blocked Users")
        .overlay {
            if moderationService.isLoading && moderationService.blockedUsers.isEmpty {
                ProgressView("Loading...")
            }
        }
        .refreshable {
            await loadBlockedUsers()
        }
        .task {
            await loadBlockedUsers()
        }
        .confirmationDialog(
            "Unblock User",
            isPresented: $showingUnblockConfirmation,
            presenting: userToUnblock
        ) { user in
            Button("Unblock \(user.blockedUserName)", role: .destructive) {
                unblockUser(user)
            }
            Button("Cancel", role: .cancel) {}
        } message: { user in
            Text("You will see galleries from \(user.blockedUserName) in Explore again.")
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "person.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)

                Text("No Blocked Users")
                    .font(.headline)

                Text("When you block a user, their galleries will no longer appear in your Explore feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private var blockedUsersSection: some View {
        Section {
            ForEach(moderationService.blockedUsers) { blockedUser in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(blockedUser.blockedUserName)
                            .font(.body)

                        Text("Blocked \(blockedUser.createdAt, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        userToUnblock = blockedUser
                        showingUnblockConfirmation = true
                    } label: {
                        Text("Unblock")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Blocked Users")
        } footer: {
            Text("Blocked users' galleries won't appear in your Explore feed. Unblocking will allow their content to appear again.")
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
        }
    }

    // MARK: - Actions

    private func loadBlockedUsers() async {
        errorMessage = nil
        do {
            _ = try await moderationService.fetchBlockedUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblockUser(_ user: BlockedUser) {
        Task {
            do {
                try await moderationService.unblockUser(user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
    }
}
