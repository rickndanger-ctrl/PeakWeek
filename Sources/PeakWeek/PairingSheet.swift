import SwiftUI
import CoreImage.CIFilterBuiltins

/// Pair a lifter's iPhone with their roster entry: mints a one-use 24-hour
/// code on the server and shows it big, plus a QR the phone can scan. The
/// phone exchanges the code once for a device token — unpair any time.
struct PairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let client: Client

    @State private var code: String?
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pair iPhone — \(client.name)").font(.title3).bold()
            Text("One code, one phone, 24 hours to use it. In the PeakWeek app on their phone they type this code (or scan the QR) and they're connected — results they log land straight in your inbox.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let code {
                HStack(spacing: 18) {
                    Text(code)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .kerning(4)
                        .textSelection(.enabled)
                    if let qr = qrImage("peakweek://pair?code=\(code)") {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 110, height: 110)
                    }
                }
                .frame(maxWidth: .infinity)
                Button("Copy code") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                }
                .buttonStyle(.bordered)
            } else if working {
                ProgressView().frame(maxWidth: .infinity)
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Unpair all devices", role: .destructive) {
                    Task {
                        await SyncService.unpair(clientID: client.id)
                        error = "All of \(client.name)'s devices unpaired."
                    }
                }
                .buttonStyle(.borderless).font(.caption)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 430)
        .task {
            guard code == nil else { return }
            working = true
            defer { working = false }
            do { code = try await SyncService.mintPairingCode(for: client) }
            catch { self.error = error.localizedDescription }
        }
    }

    private func qrImage(_ string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: scaled)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }
}
