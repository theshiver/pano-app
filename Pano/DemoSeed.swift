#if DEBUG
    import AppKit
    import PanoCore
    import PanoStore

    /// Demo history for website screenshots. Debug builds only; runs when launched with
    ///   open --env PANO_STORE_FOLDER=Pano-demo --env PANO_SEED=1 Pano.app
    /// The container is TCC-protected, so seeding has to happen inside the app.
    enum DemoSeed {
        struct Seed {
            var kind: Clip.Kind
            var text: String
            var app: (id: String, name: String)
            var minutesAgo: Double
            var secret = false
        }

        static let xcode = ("com.apple.dt.Xcode", "Xcode")
        static let safari = ("com.apple.Safari", "Safari")
        static let code = ("com.microsoft.VSCode", "Visual Studio Code")
        static let terminal = ("com.apple.Terminal", "Terminal")
        static let tablePlus = ("com.tinyapp.TablePlus", "TablePlus")
        static let postman = ("com.postmanlabs.mac", "Postman")
        static let notes = ("com.apple.Notes", "Notes")
        static let chrome = ("com.google.Chrome", "Google Chrome")

        static let seeds: [Seed] = [
            Seed(
                kind: .code,
                text: """
                    struct ClipRow: View {
                        let clip: ClipListItem
                        var body: some View {
                            HStack(spacing: 8) {
                                AppIcon(bundleId: clip.sourceBundleId)
                                Text(clip.content ?? "").lineLimit(1)
                            }
                        }
                    }
                    """, app: xcode, minutesAgo: 2),
            Seed(
                kind: .text,
                text: """
                    {"id":"clp_9f2a","kind":"code","format":"json","language":"swift","source":{"bundle":"com.apple.dt.Xcode","name":"Xcode"},"pinned":true,"tags":["ui","review"],"created_at":"2026-09-18T14:02:11Z"}
                    """, app: postman, minutesAgo: 5),
            Seed(kind: .colour, text: "#2A6DF0", app: safari, minutesAgo: 8),
            Seed(
                kind: .code,
                text: """
                    export async function fetchClips(query: string): Promise<Clip[]> {
                      const res = await fetch(`/api/clips?q=${encodeURIComponent(query)}`);
                      if (!res.ok) throw new Error(`HTTP ${res.status}`);
                      return res.json();
                    }
                    """, app: code, minutesAgo: 12),
            Seed(
                kind: .code,
                text: """
                    SELECT c.id, c.kind, c.source_name, count(p.clip_id) AS boards
                    FROM clip c
                    LEFT JOIN pinboard_clip p ON p.clip_id = c.id
                    WHERE c.created_at > datetime('now', '-7 days')
                    GROUP BY c.id
                    ORDER BY c.last_seen_at DESC;
                    """, app: tablePlus, minutesAgo: 15),
            Seed(
                kind: .code,
                text: """
                    #!/bin/sh
                    xcodebuild build -project Pano.xcodeproj -scheme Pano \\
                      -destination 'platform=macOS' -derivedDataPath build/DerivedData
                    """, app: terminal, minutesAgo: 20),
            Seed(
                kind: .url, text: "https://developer.apple.com/documentation/appkit/nspasteboard", app: safari,
                minutesAgo: 25),
            Seed(
                kind: .text,
                text:
                    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfNDgyMSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc1ODIwMDAwMCwiZXhwIjoxNzU4MjAzNjAwfQ.k3jP0Qz7Yx2mN9vB1cD4eF5gH6iJ7kL8mN9oP0qR1sT",
                app: postman, minutesAgo: 30, secret: true),
            Seed(
                kind: .code,
                text: """
                    # Release checklist
                    - [x] Bump version in project.yml
                    - [ ] Run `swift test` in every package
                    - [ ] Notarize the DMG
                    > Ship only when CI is green.
                    """, app: notes, minutesAgo: 40),
            Seed(
                kind: .text,
                text:
                    "The panel opens next to your cursor, you type a few letters, press return, and the clip lands in the app you were in.",
                app: chrome, minutesAgo: 45),
            Seed(
                kind: .code,
                text: """
                    .panel {
                      display: grid;
                      grid-template-columns: 56px 1fr 1.2fr;
                      background: color-mix(in oklab, var(--bg) 92%, transparent);
                      backdrop-filter: blur(24px);
                    }
                    """, app: code, minutesAgo: 60),
            Seed(
                kind: .code,
                text: """
                    def dedup(clips):
                        seen = set()
                        for clip in clips:
                            if clip.content_hash in seen:
                                continue
                            seen.add(clip.content_hash)
                            yield clip
                    """, app: code, minutesAgo: 120),
            Seed(
                kind: .text, text: "UGFubyBrZWVwcyBldmVyeXRoaW5nIG9uIHlvdXIgTWFjLiBObyBzeW5jLCBubyBhY2NvdW50Lg==",
                app: terminal, minutesAgo: 180),
            Seed(kind: .colour, text: "rgb(255, 122, 92)", app: safari, minutesAgo: 240),
            Seed(
                kind: .text, text: "feat(panel): source-app rail with per-app filtering", app: terminal, minutesAgo: 300
            ),
            Seed(kind: .text, text: "Keyboard-first clipboard manager for macOS", app: notes, minutesAgo: 360),
        ]

        /// Renders a terminal-style build error, the kind of screenshot people paste into chat.
        private static func errorScreenshot() -> Data {
            let lines = [
                ("error: ", "cannot find 'ClipListItem' in scope", NSColor(red: 1, green: 0.42, blue: 0.42, alpha: 1)),
                ("  --> ", "PanoUI/Sources/PanoUI/ClipRow.swift:14:20", nil),
                ("14 | ", "    let clip: ClipListItem", nil),
                ("   | ", "              ^~~~~~~~~~~~", NSColor(red: 0.4, green: 0.8, blue: 1, alpha: 1)),
                (
                    "help: ", "add `import PanoStore` to the top of the file",
                    NSColor(red: 0.55, green: 0.9, blue: 0.6, alpha: 1)
                ),
            ]
            let width = 1240, height = 60 + lines.count * 44
            guard
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            else { return Data() }
            rep.size = NSSize(width: width, height: height)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            let font = NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
            for (index, line) in lines.enumerated() {
                let y = CGFloat(height - 52 - index * 44)
                let prefix = NSAttributedString(
                    string: line.0,
                    attributes: [.font: font, .foregroundColor: line.2 ?? NSColor(white: 0.55, alpha: 1)])
                prefix.draw(at: NSPoint(x: 36, y: y))
                NSAttributedString(
                    string: line.1, attributes: [.font: font, .foregroundColor: NSColor(white: 0.92, alpha: 1)]
                ).draw(at: NSPoint(x: 36 + prefix.size().width, y: y))
            }
            NSGraphicsContext.restoreGraphicsState()
            return rep.representation(using: .png, properties: [:]) ?? Data()
        }

        @MainActor static func run(_ store: Store) async throws {
            // Every launch starts from the same state (clearHistory would keep pinned and board members).
            for board in try await store.pinboards() { try await store.deletePinboard(id: board.id) }
            for item in try await store.recent(limit: 10_000) { try await store.delete(id: item.id) }
            let now = Date()
            var ids: [Int64] = []
            for seed in seeds.reversed() {
                let capture = ClipCapture(
                    kind: seed.kind,
                    content: seed.text,
                    representations: [.init(uti: "public.utf8-plain-text", data: Data(seed.text.utf8))],
                    sourceBundleId: seed.app.id,
                    sourceName: seed.app.name,
                    sensitivity: seed.secret ? .secret : .none,
                    isMasked: seed.secret
                )
                ids.append(try await store.insert(capture, now: now.addingTimeInterval(-seed.minutesAgo * 60)))
            }
            ids.reverse()  // newest first, matching `seeds`

            if let tiff = NSApp.applicationIconImage.tiffRepresentation,
                let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            {
                let image = ClipCapture(
                    kind: .image, content: nil, representations: [.init(uti: "public.png", data: png)],
                    sourceBundleId: "com.apple.Preview", sourceName: "Preview")
                try await store.insert(image, now: now.addingTimeInterval(-50 * 60))
            }

            // A screenshot of a compiler error, run through the real OCR so the site shows searchable image text.
            let shot = errorScreenshot()
            let shotId = try await store.insert(
                ClipCapture(
                    kind: .image, content: nil, representations: [.init(uti: "public.png", data: shot)],
                    sourceBundleId: xcode.0, sourceName: xcode.1),
                now: now.addingTimeInterval(-10 * 60))
            if let text = await OCRService.recognizeText(in: shot) { try await store.setOCRText(text, id: shotId) }

            let snippets = try await store.createPinboard(name: "Snippets", colour: "#8B5CF6", icon: nil)
            for index in [0, 4, 5] { try await store.addToPinboard(clipId: ids[index], pinboardId: snippets) }
            let brand = try await store.createPinboard(name: "Brand", colour: "#F59E0B", icon: nil)
            for index in [2, 13] { try await store.addToPinboard(clipId: ids[index], pinboardId: brand) }
            try await store.setPinned(true, id: ids[1])
            try await store.setPinned(true, id: ids[2])
        }
    }
#endif
