import AppKit
import SwiftUI

public struct OnboardingView: View {
    private let hotKeyDisplay: String
    private let supportsAutoPaste: Bool
    private let onStart: (_ loadSamples: Bool, _ enableAutoPaste: Bool) -> Void

    @State private var loadSampleClips = true
    @State private var enableAutoPaste = true
    @Environment(\.colorScheme) private var scheme

    public static let width: CGFloat = 460

    public init(
        hotKeyDisplay: String = "⌘⇧V",
        supportsAutoPaste: Bool = false,
        onStart: @escaping (_ loadSamples: Bool, _ enableAutoPaste: Bool) -> Void
    ) {
        self.hotKeyDisplay = hotKeyDisplay
        self.supportsAutoPaste = supportsAutoPaste
        self.onStart = onStart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Welcome to Pano")
                        .font(.system(size: 21, weight: .bold))
                        .tracking(-0.3)
                    Text("Local-only clipboard history for macOS.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                featureRow(
                    symbol: "keyboard",
                    title: "Open anywhere with \(hotKeyDisplay)",
                    detail: supportsAutoPaste
                        ? "Search by word, type:code, or app:xcode. Press Return to paste."
                        : "Search by word, type:code, or app:xcode. Press Return to copy, then ⌘V."
                )
                featureRow(
                    symbol: "wand.and.stars",
                    title: "Transform as you type",
                    detail: "Type json, jwt, b64, or copy a hex colour to convert formats on the fly."
                )
                featureRow(
                    symbol: "text.viewfinder",
                    title: "Screenshots become searchable",
                    detail: "On-device Apple Vision OCR indexes text inside images. Press ⇧⏎ to copy the text."
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.brandAccent)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard permission")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(
                        "macOS asks once when Pano reads your clipboard. Choose Always Allow in System Settings so it stays seamless."
                    )
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.warmSand.opacity(scheme == .dark ? 0.08 : 0.45))
            )
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Load 3 sample clips to try JSON, colours, and OCR", isOn: $loadSampleClips)
                    .font(.system(size: 12.5))
                if supportsAutoPaste {
                    Toggle("Enable automatic paste on Return (uses Accessibility)", isOn: $enableAutoPaste)
                        .font(.system(size: 12.5))
                }
            }
            .padding(.top, 14)

            Button {
                onStart(loadSampleClips, supportsAutoPaste && enableAutoPaste)
            } label: {
                HStack(spacing: 6) {
                    Text("Start Using Pano")
                    Text(hotKeyDisplay).opacity(0.75)
                }
                .font(.system(size: 13.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandAccent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .pointer()
            .padding(.top, 16)

            Text("Free and open source (MIT). Zero telemetry, zero network access.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 32, leading: 26, bottom: 20, trailing: 26))
        .frame(width: Self.width)
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.brandAccent)
                .frame(width: 24, height: 24)
                .background(Theme.brandAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
