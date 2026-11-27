import Foundation

@MainActor
@Observable
public final class UpdateModel {
    public struct Release: Equatable, Sendable {
        public let version: String
        public let notes: String
        public let releasePageURL: URL
        public let downloadURL: URL?

        public init(version: String, notes: String, releasePageURL: URL, downloadURL: URL?) {
            self.version = version
            self.notes = notes
            self.releasePageURL = releasePageURL
            self.downloadURL = downloadURL
        }
    }

    public enum Status: Equatable, Sendable {
        case idle
        case checking
        case upToDate(checkedAt: Date)
        case available(Release)
        case downloading(Release, progress: Double?)
        case installing(Release)
        case openedInstaller(Release, message: String)
        case failed(message: String, fallbackURL: URL?)
    }

    public var status: Status = .idle
    public var lastCheckedAt: Date?
    public var dismissedBadgeVersion: String?

    public var availableRelease: Release? {
        switch status {
        case .available(let release),
            .downloading(let release, _),
            .installing(let release),
            .openedInstaller(let release, _):
            return release
        case .idle, .checking, .upToDate, .failed:
            return nil
        }
    }

    public var isBusy: Bool {
        switch status {
        case .checking, .downloading, .installing:
            return true
        case .idle, .upToDate, .available, .openedInstaller, .failed:
            return false
        }
    }

    public var badgeVersion: String? {
        guard let version = availableRelease?.version else { return nil }
        return version == dismissedBadgeVersion ? nil : version
    }

    private let onCheck: () -> Void
    private let onInstall: () -> Void
    private let onDismissBadge: (String) -> Void
    private let onAutomaticChecksChanged: (Bool) -> Void

    public init(
        lastCheckedAt: Date? = nil,
        dismissedBadgeVersion: String? = nil,
        onCheck: @escaping () -> Void = {},
        onInstall: @escaping () -> Void = {},
        onDismissBadge: @escaping (String) -> Void = { _ in },
        onAutomaticChecksChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.lastCheckedAt = lastCheckedAt
        self.dismissedBadgeVersion = dismissedBadgeVersion
        self.onCheck = onCheck
        self.onInstall = onInstall
        self.onDismissBadge = onDismissBadge
        self.onAutomaticChecksChanged = onAutomaticChecksChanged
    }

    public func checkNow() {
        onCheck()
    }

    public func installAvailable() {
        onInstall()
    }

    public func dismissBadge(for version: String) {
        dismissedBadgeVersion = version
        onDismissBadge(version)
    }

    public func setAutomaticChecks(_ enabled: Bool) {
        onAutomaticChecksChanged(enabled)
    }
}
