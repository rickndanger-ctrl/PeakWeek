import SwiftUI

/// A quick note to your coach — no lift attached. Lands in their inbox with
/// a notification. Conversation continues in Messages, as always.
struct NoteComposeView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var body_ = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Shoulder's been cranky on bench… / Traveling next week… / Question about the pause squats…",
                              text: $body_, axis: .vertical)
                        .lineLimit(4...10)
                } footer: {
                    Text("Goes straight to your coach's inbox. For back-and-forth, texts still work best.")
                }
            }
            .navigationTitle("Note to coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        session.submitNote(body_)
                        dismiss()
                    }
                    .bold()
                    .disabled(body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
