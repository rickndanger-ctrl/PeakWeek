import SwiftUI

/// First run: type the code your coach shows you. Once. That's the whole
/// setup — no account, no password.
struct PairView: View {
    @EnvironmentObject var session: Session
    @State private var code = ""
    @State private var working = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            VStack(spacing: 8) {
                Text("PEAK WEEK")
                    .font(.system(size: 40, weight: .black))
                    .kerning(1)
                Text("Your coach, in your pocket.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("PAIRING CODE").font(.caption2).kerning(1.5)
                    .foregroundStyle(.secondary)
                TextField("8 characters", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(Rectangle().stroke(Color(.separator), lineWidth: 0.5))
                Text("Your coach generates this from their PeakWeek app — it works once and expires in 24 hours.")
                    .font(.caption).foregroundStyle(.secondary)
                if let err = session.lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)

            Button {
                working = true
                Task {
                    await session.pair(code: code)
                    working = false
                }
            } label: {
                if working {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 6)
                } else {
                    Text("Connect").bold().frame(maxWidth: .infinity).padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespaces).count < 6 || working)
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
