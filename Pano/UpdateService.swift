#if DIRECT_DISTRIBUTION
    import AppKit
    import Foundation
    import PanoCore
    import PanoUI

    @MainActor
    final class UpdateService {
        private static let latestReleaseAPI =
            URL(string: "https://api.github.com/repos/theshiver/pano-app/releases/latest")
            ?? URL(fileURLWithPath: "/")
        private static let releasesPageURL =
            URL(string: "https://github.com/theshiver/pano-app/releases/latest")
            ?? URL(fileURLWithPath: "/")
        private static let expectedBundleId = "com.cancetin.pano"
        private static let expectedTeamId = "S2RH54MMT3"
        private static let checkInterval: TimeInterval = 86_400

        private let prefs: Preferences
        private let onStatusChanged: () -> Void
        private var periodicTask: Task<Void, Never>?
        private var activeTask: Task<Void, Never>?

        lazy var model: UpdateModel = UpdateModel(
            lastCheckedAt: prefs.lastUpdateCheckDate,
            dismissedBadgeVersion: prefs.dismissedUpdateVersion,
            onCheck: { [weak self] in self?.check(userInitiated: true) },
            onInstall: { [weak self] in self?.installAvailable() },
            onDismissBadge: { [weak self] version in
                self?.prefs.dismissedUpdateVersion = version
                self?.onStatusChanged()
            },
            onAutomaticChecksChanged: { [weak self] enabled in
                self?.setAutomaticChecks(enabled)
            }
        )

        init(prefs: Preferences, onStatusChanged: @escaping () -> Void) {
            self.prefs = prefs
            self.onStatusChanged = onStatusChanged
        }

        func startIfEnabled() {
            periodicTask?.cancel()
            periodicTask = nil
            guard prefs.automaticallyChecksForUpdates else { return }

            periodicTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                while !Task.isCancelled {
                    guard let self else { return }
                    let due: Bool
                    if let last = self.prefs.lastUpdateCheckDate {
                        due = Date().timeIntervalSince(last) >= Self.checkInterval
                    } else {
                        due = true
                    }
                    if due, !self.model.isBusy {
                        await self.performCheck(userInitiated: false)
                    }
                    try? await Task.sleep(for: .seconds(3600))
                }
            }
        }

        func setAutomaticChecks(_ enabled: Bool) {
            prefs.automaticallyChecksForUpdates = enabled
            if enabled {
                startIfEnabled()
            } else {
                periodicTask?.cancel()
                periodicTask = nil
            }
        }

        func check(userInitiated: Bool) {
            guard !model.isBusy else { return }
            activeTask?.cancel()
            activeTask = Task { [weak self] in
                await self?.performCheck(userInitiated: userInitiated)
            }
        }

        func installAvailable() {
            guard let release = model.availableRelease, !model.isBusy else { return }
            guard let downloadURL = release.downloadURL else {
                NSWorkspace.shared.open(release.releasePageURL)
                return
            }
            activeTask?.cancel()
            activeTask = Task { [weak self] in
                await self?.performInstall(release: release, downloadURL: downloadURL)
            }
        }

        // MARK: Check

        private func performCheck(userInitiated: Bool) async {
            if userInitiated {
                model.status = .checking
                onStatusChanged()
            }

            do {
                let githubRelease = try await fetchLatestRelease()
                let now = Date()
                prefs.lastUpdateCheckDate = now
                model.lastCheckedAt = now

                let rawTag = githubRelease.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                let parsedLatest = AppVersion(rawTag)
                let parsedCurrent = AppVersion(Preferences.marketingVersion)

                let isNewer: Bool
                if !githubRelease.draft, !githubRelease.prerelease, let parsedLatest {
                    if let parsedCurrent {
                        isNewer = parsedLatest > parsedCurrent
                    } else {
                        isNewer = false
                    }
                } else {
                    isNewer = false
                }

                if isNewer, let parsedLatest {
                    let release = buildRelease(from: githubRelease, version: parsedLatest.description)
                    model.status = .available(release)
                } else if userInitiated || model.availableRelease != nil {
                    model.status = .upToDate(checkedAt: now)
                }
                onStatusChanged()
            } catch is CancellationError {
                return
            } catch {
                if userInitiated {
                    model.status = .failed(
                        message: error.localizedDescription,
                        fallbackURL: Self.releasesPageURL
                    )
                    onStatusChanged()
                }
            }
        }

        private func fetchLatestRelease(allowETag: Bool = true) async throws -> GitHubRelease {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 15
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil

            let session = URLSession(configuration: configuration)
            defer { session.finishTasksAndInvalidate() }

            var request = URLRequest(url: Self.latestReleaseAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Pano/\(Preferences.marketingVersion) (macOS)", forHTTPHeaderField: "User-Agent")
            if allowETag, prefs.cachedReleaseData != nil, let etag = prefs.updateCheckETag {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }

            if http.statusCode == 304 {
                if let cached = prefs.cachedReleaseData,
                    let decoded = try? JSONDecoder().decode(GitHubRelease.self, from: cached)
                {
                    return decoded
                }
                prefs.updateCheckETag = nil
                prefs.cachedReleaseData = nil
                if allowETag {
                    return try await fetchLatestRelease(allowETag: false)
                }
                throw UpdateError.invalidResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                throw UpdateError.httpStatus(http.statusCode)
            }

            let decoded = try JSONDecoder().decode(GitHubRelease.self, from: data)
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                prefs.updateCheckETag = etag
            }
            prefs.cachedReleaseData = data
            return decoded
        }

        private func buildRelease(from githubRelease: GitHubRelease, version: String) -> UpdateModel.Release {
            let pageURL = Self.validatedPageURL(githubRelease.htmlURL)
            let notes = (githubRelease.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredName = "pano-\(version).dmg"

            let dmgAssets = githubRelease.assets.filter {
                $0.name.lowercased().hasSuffix(".dmg")
            }
            let selectedAsset =
                dmgAssets.first { $0.name.lowercased() == preferredName }
                ?? dmgAssets.first
            let downloadURL = selectedAsset.flatMap { Self.validatedAssetURL($0.browserDownloadURL) }

            return UpdateModel.Release(
                version: version,
                notes: notes,
                releasePageURL: pageURL,
                downloadURL: downloadURL
            )
        }

        private static func validatedPageURL(_ raw: String) -> URL {
            guard let url = URL(string: raw),
                url.scheme?.lowercased() == "https",
                url.host?.lowercased() == "github.com"
            else {
                return releasesPageURL
            }
            return url
        }

        private static func validatedAssetURL(_ raw: String) -> URL? {
            guard let url = URL(string: raw),
                url.scheme?.lowercased() == "https",
                let host = url.host?.lowercased(),
                host == "github.com" || host == "objects.githubusercontent.com"
            else {
                return nil
            }
            return url
        }

        // MARK: Install

        private func performInstall(release: UpdateModel.Release, downloadURL: URL) async {
            model.status = .downloading(release, progress: nil)
            onStatusChanged()

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("pano-update-\(UUID().uuidString)", isDirectory: true)
            let dmgURL = tempDir.appendingPathComponent("Pano-\(release.version).dmg")
            let mountDir = tempDir.appendingPathComponent("mount", isDirectory: true)
            var mounted = false
            var stagedURL: URL?

            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)

                _ = try await downloadDMG(from: downloadURL, to: dmgURL) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.model.status = .downloading(release, progress: progress)
                    }
                }

                model.status = .installing(release)
                onStatusChanged()

                let attach = try await Self.runProcess(
                    executable: "/usr/bin/hdiutil",
                    arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountDir.path]
                )
                guard attach.status == 0 else {
                    throw UpdateError.mountFailed
                }
                mounted = true

                let mountedApp = mountDir.appendingPathComponent("Pano.app")
                try await Self.verifySignedApp(at: mountedApp, expectedVersion: release.version)

                if let targetURL = Self.inPlaceTargetURL() {
                    let targetDir = targetURL.deletingLastPathComponent()
                    let staged = targetDir.appendingPathComponent(".Pano-update-\(UUID().uuidString).app")
                    stagedURL = staged

                    let copy = try await Self.runProcess(
                        executable: "/usr/bin/ditto",
                        arguments: [mountedApp.path, staged.path]
                    )
                    guard copy.status == 0 else {
                        throw UpdateError.installFailed
                    }

                    await Self.detachMount(at: mountDir)
                    mounted = false
                    try? FileManager.default.removeItem(at: tempDir)

                    try Self.launchRelaunchScript(stagedURL: staged, targetURL: targetURL)
                    stagedURL = nil
                    NSApp.terminate(nil)
                    return
                }

                await Self.detachMount(at: mountDir)
                mounted = false

                let downloadsURL = try Self.moveDMGToDownloads(from: dmgURL, version: release.version)
                try? FileManager.default.removeItem(at: tempDir)
                NSWorkspace.shared.open(downloadsURL)

                model.status = .openedInstaller(
                    release,
                    message: "Opened \(downloadsURL.lastPathComponent). Drag Pano to Applications to finish updating."
                )
                onStatusChanged()
            } catch is CancellationError {
                if mounted {
                    await Self.detachMount(at: mountDir)
                }
                if let stagedURL {
                    try? FileManager.default.removeItem(at: stagedURL)
                }
                try? FileManager.default.removeItem(at: tempDir)
            } catch {
                if mounted {
                    await Self.detachMount(at: mountDir)
                }
                if let stagedURL {
                    try? FileManager.default.removeItem(at: stagedURL)
                }
                try? FileManager.default.removeItem(at: tempDir)
                model.status = .failed(
                    message: error.localizedDescription,
                    fallbackURL: release.releasePageURL
                )
                onStatusChanged()
            }
        }

        private func downloadDMG(
            from url: URL,
            to destinationURL: URL,
            onProgress: @escaping @Sendable (Double?) -> Void
        ) async throws -> URL {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 30
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil

            let delegate = DownloadDelegate(destinationURL: destinationURL, onProgress: onProgress)
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }

            let task = session.downloadTask(with: url)
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    delegate.start(task: task, continuation: continuation)
                }
            } onCancel: {
                task.cancel()
            }
        }

        private static func verifySignedApp(at appURL: URL, expectedVersion: String) async throws {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: appURL.path, isDirectory: &isDirectory), isDirectory.boolValue
            else {
                throw UpdateError.invalidArchive
            }

            let verify = try await runProcess(
                executable: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", appURL.path]
            )
            guard verify.status == 0 else {
                throw UpdateError.verificationFailed
            }

            // `codesign -dv` writes signing identity details to stderr.
            let details = try await runProcess(
                executable: "/usr/bin/codesign",
                arguments: ["-dv", "--verbose=4", appURL.path]
            )
            guard details.status == 0 else {
                throw UpdateError.verificationFailed
            }

            let lines = details.stderr.components(separatedBy: .newlines)
            guard lines.contains("Identifier=\(expectedBundleId)"),
                lines.contains("TeamIdentifier=\(expectedTeamId)"),
                lines.contains(where: { $0.hasPrefix("Authority=Developer ID Application:") })
            else {
                throw UpdateError.verificationFailed
            }

            let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
            let plistData = try Data(contentsOf: plistURL)
            let rawPlist = try PropertyListSerialization.propertyList(from: plistData, format: nil)
            guard let plist = rawPlist as? [String: Any],
                let bundleId = plist["CFBundleIdentifier"] as? String,
                bundleId == expectedBundleId,
                let shortVersion = plist["CFBundleShortVersionString"] as? String,
                let mountedVersion = AppVersion(shortVersion),
                let targetVersion = AppVersion(expectedVersion),
                mountedVersion >= targetVersion
            else {
                throw UpdateError.verificationFailed
            }
        }

        private static func detachMount(at mountDir: URL) async {
            _ = try? await runProcess(
                executable: "/usr/bin/hdiutil",
                arguments: ["detach", mountDir.path, "-quiet"]
            )
        }

        private static func inPlaceTargetURL() -> URL? {
            let bundleURL = Bundle.main.bundleURL.standardizedFileURL
            guard bundleURL.pathExtension == "app" else { return nil }
            let path = bundleURL.path
            guard !path.contains("/AppTranslocation/"), !path.hasPrefix("/Volumes/") else { return nil }

            let parent = bundleURL.deletingLastPathComponent().standardizedFileURL
            let allowedDirs = [
                FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first?.standardizedFileURL,
                FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first?.standardizedFileURL,
            ].compactMap { $0 }

            let inApplications = allowedDirs.contains { dir in
                parent == dir || parent.path.hasPrefix(dir.path + "/")
            }
            guard inApplications, FileManager.default.isWritableFile(atPath: parent.path) else {
                return nil
            }
            return bundleURL
        }

        private static func moveDMGToDownloads(from sourceURL: URL, version: String) throws -> URL {
            let downloads =
                FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            var candidate = downloads.appendingPathComponent("Pano-\(version).dmg")
            var suffix = 2
            while FileManager.default.fileExists(atPath: candidate.path) {
                candidate = downloads.appendingPathComponent("Pano-\(version)-\(suffix).dmg")
                suffix += 1
            }
            try FileManager.default.copyItem(at: sourceURL, to: candidate)
            return candidate
        }

        private static func launchRelaunchScript(stagedURL: URL, targetURL: URL) throws {
            let script = """
                pid="$1"
                staged="$2"
                target="$3"
                backup="${target}.pano-update-backup"
                i=0
                while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 100 ]; do
                  sleep 0.1
                  i=$((i + 1))
                done
                rm -rf "$backup"
                if mv "$target" "$backup" && mv "$staged" "$target"; then
                  rm -rf "$backup"
                  open "$target"
                else
                  [ -d "$backup" ] && [ ! -e "$target" ] && mv "$backup" "$target"
                  rm -rf "$staged"
                  exit 1
                fi
                """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                "-c",
                script,
                "pano-updater",
                String(ProcessInfo.processInfo.processIdentifier),
                stagedURL.path,
                targetURL.path,
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
        }

        private static func runProcess(
            executable: String,
            arguments: [String]
        ) async throws -> (status: Int32, stdout: String, stderr: String) {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: error)
                        return
                    }

                    let group = DispatchGroup()
                    var outData = Data()
                    var errData = Data()

                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        group.leave()
                    }

                    group.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        group.leave()
                    }

                    group.wait()
                    process.waitUntilExit()

                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, stdout, stderr))
                }
            }
        }
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let htmlURL: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case htmlURL = "html_url"
            case draft
            case prerelease
            case assets
        }
    }

    private enum UpdateError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case mountFailed
        case invalidArchive
        case verificationFailed
        case installFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Could not read release information from GitHub."
            case .httpStatus(let code):
                return "Update check failed (HTTP \(code))."
            case .mountFailed:
                return "Could not open the downloaded disk image."
            case .invalidArchive:
                return "The downloaded disk image did not contain Pano.app."
            case .verificationFailed:
                return "Update signature verification failed."
            case .installFailed:
                return "Could not stage the new version for installation."
            }
        }
    }

    private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        private let destinationURL: URL
        private let onProgress: @Sendable (Double?) -> Void
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL, Error>?
        private var finished = false

        init(destinationURL: URL, onProgress: @escaping @Sendable (Double?) -> Void) {
            self.destinationURL = destinationURL
            self.onProgress = onProgress
        }

        func start(task: URLSessionDownloadTask, continuation: CheckedContinuation<URL, Error>) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            task.resume()
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            let progress: Double? =
                totalBytesExpectedToWrite > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                : nil
            onProgress(progress)
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            // URLSession deletes the temporary file at `location` as soon as this method returns.
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)
                resumeOnce(with: .success(destinationURL))
            } catch {
                resumeOnce(with: .failure(error))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error {
                resumeOnce(with: .failure(error))
            }
        }

        private func resumeOnce(with result: Result<URL, Error>) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            finished = true
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(with: result)
        }
    }
#endif
