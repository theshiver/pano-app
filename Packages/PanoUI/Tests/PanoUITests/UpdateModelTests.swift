import Foundation
import Testing

@testable import PanoUI

@MainActor
@Test func availableReleaseAndBusyStates() {
    let model = UpdateModel()
    let releaseURL = URL(fileURLWithPath: "/tmp/release")
    let release = UpdateModel.Release(
        version: "1.2",
        notes: "Fixes",
        releasePageURL: releaseURL,
        downloadURL: releaseURL
    )

    #expect(model.availableRelease == nil)
    #expect(!model.isBusy)

    model.status = .checking
    #expect(model.availableRelease == nil)
    #expect(model.isBusy)

    model.status = .upToDate(checkedAt: Date())
    #expect(model.availableRelease == nil)
    #expect(!model.isBusy)

    model.status = .available(release)
    #expect(model.availableRelease == release)
    #expect(!model.isBusy)

    model.status = .downloading(release, progress: 0.5)
    #expect(model.availableRelease == release)
    #expect(model.isBusy)

    model.status = .installing(release)
    #expect(model.availableRelease == release)
    #expect(model.isBusy)

    model.status = .openedInstaller(release, message: "Opened")
    #expect(model.availableRelease == release)
    #expect(!model.isBusy)

    model.status = .failed(message: "Failed", fallbackURL: releaseURL)
    #expect(model.availableRelease == nil)
    #expect(!model.isBusy)
}

@MainActor
@Test func badgeDismissalOnlyHidesDismissedVersion() {
    var dismissedVersion: String?
    let model = UpdateModel(onDismissBadge: { dismissedVersion = $0 })
    let pageURL = URL(fileURLWithPath: "/tmp/release")
    let v12 = UpdateModel.Release(version: "1.2", notes: "", releasePageURL: pageURL, downloadURL: nil)
    let v13 = UpdateModel.Release(version: "1.3", notes: "", releasePageURL: pageURL, downloadURL: nil)

    model.status = .available(v12)
    #expect(model.badgeVersion == "1.2")

    model.dismissBadge(for: "1.2")
    #expect(dismissedVersion == "1.2")
    #expect(model.badgeVersion == nil)

    model.status = .available(v13)
    #expect(model.badgeVersion == "1.3")
}
