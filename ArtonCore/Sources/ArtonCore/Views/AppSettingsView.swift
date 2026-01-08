import SwiftUI

/// Settings view with contact info, ToS, privacy policy, and blocked users
public struct AppSettingsView: View {
    @StateObject private var moderationService = ContentModerationService.shared

    public init() {}

    public var body: some View {
        List {
            #if !os(tvOS)
            privacySection

            betaFeedbackSection
            #endif

            aboutSection

            legalSection
        }
        #if os(iOS)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        #elseif os(macOS) || os(tvOS)
        .navigationTitle("Settings")
        #endif
    }

    // MARK: - Privacy Section

    #if !os(tvOS)
    private var privacySection: some View {
        Section {
            NavigationLink {
                BlockedUsersView()
            } label: {
                HStack {
                    Label("Blocked Users", systemImage: "person.slash")

                    Spacer()

                    if !moderationService.blockedUsers.isEmpty {
                        Text("\(moderationService.blockedUsers.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Privacy & Safety")
        } footer: {
            Text("Blocked users' galleries won't appear in your Explore feed.")
        }
    }

    private var betaFeedbackSection: some View {
        Section {
            Link(destination: feedbackMailtoURL) {
                HStack {
                    Label("Send Feedback", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Beta")
        } footer: {
            Text("Help us improve Arton by sharing your feedback.")
        }
    }

    private var feedbackMailtoURL: URL {
        let subject = "Arton Beta Feedback"
        let body = "App Version: \(appVersion)\n\n"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        return URL(string: "mailto:\(ContentModerationService.supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")!
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "mailto:\(ContentModerationService.supportEmail)")!) {
                HStack {
                    Label("Contact Support", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(iOS) || os(macOS)
            .foregroundStyle(.primary)
            #endif
        } header: {
            Text("About")
        } footer: {
            Text("Have a question or feedback? We'd love to hear from you.")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            Link(destination: ContentModerationService.termsOfServiceURL) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(iOS) || os(macOS)
            .foregroundStyle(.primary)
            #endif

            Link(destination: ContentModerationService.privacyPolicyURL) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(iOS) || os(macOS)
            .foregroundStyle(.primary)
            #endif

            Link(destination: ContentModerationService.communityGuidelinesURL) {
                HStack {
                    Label("Community Guidelines", systemImage: "person.2")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            #if os(iOS) || os(macOS)
            .foregroundStyle(.primary)
            #endif
        } header: {
            Text("Legal")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
}
