import SwiftUI
import PeakWeekCore

/// This week's plan, exactly as the coach sent it — one week, never more.
/// Tap a main lift to log what actually happened.
struct WeekScreen: View {
    @EnvironmentObject var session: Session
    @State private var logTarget: LogTarget?

    struct LogTarget: Identifiable {
        var id: String { "\(dayTitle)-\(loggable.slotIndex)" }
        let dayTitle: String
        let loggable: PublishedWeek.Loggable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let week = session.week {
                    VStack(alignment: .leading, spacing: 16) {
                        header(week)
                        ForEach(Array(week.days.enumerated()), id: \.offset) { di, day in
                            dayCard(day, week: week, dayIndex: di)
                        }
                        if !week.weekNote.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("COACH NOTES").font(.caption2).kerning(1.5)
                                    .foregroundStyle(.secondary)
                                Text(week.weekNote)
                            }
                            .squareCard()
                        }
                        Text(week.footer)
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("No week here yet")
                            .font(.headline)
                        Text("Your coach hasn't published this week — check Messages, or pull to refresh.")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let err = session.lastError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(session.client?.name ?? "This Week")
            .refreshable { await session.refresh() }
            .sheet(item: $logTarget) { target in
                LogFormView(prefill: target.loggable, dayTitle: target.dayTitle)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        logTarget = nil
                        blankLog = true
                    } label: { Image(systemName: "square.and.pencil") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNote = true
                    } label: { Image(systemName: "bubble.left") }
                }
            }
            .sheet(isPresented: $blankLog) {
                LogFormView(prefill: nil, dayTitle: nil)
            }
            .sheet(isPresented: $showNote) {
                NoteComposeView()
            }
        }
    }

    @State private var blankLog = false
    @State private var showNote = false

    private func header(_ week: PublishedWeek) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Rectangle().fill(ClientTheme.phaseColor(week.phaseLabel))
                    .frame(width: 5, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK \(week.weekNum) OF \(week.totalWeeks)")
                        .font(.system(size: 17, weight: .black))
                    HStack(spacing: 6) {
                        Text(week.phaseLabel.uppercased())
                            .font(.caption2).kerning(1)
                            .foregroundStyle(ClientTheme.phaseColor(week.phaseLabel))
                        if let out = week.weeksOut {
                            Text("· \(out) wk\(out == 1 ? "" : "s") out")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if !week.dateRange.isEmpty {
                            Text("· \(week.dateRange)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func dayCard(_ day: PublishedWeek.Day, week: PublishedWeek,
                         dayIndex: Int) -> some View {
        let done = session.doneDays.contains(session.dayKey(week, dayIndex: dayIndex))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(day.title.uppercased())
                    .font(.system(size: 12, weight: .bold)).kerning(1)
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                Spacer()
                Button {
                    session.toggleDone(week, dayIndex: dayIndex)
                } label: {
                    Image(systemName: done ? "checkmark.square.fill" : "square")
                        .foregroundStyle(done ? ClientTheme.plateGreen : .secondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(day.lines.enumerated()), id: \.offset) { idx, line in
                let loggable = day.loggables.first {
                    $0.slotIndex == idx
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line)
                        .font(.system(.subheadline, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if let loggable {
                        Button {
                            logTarget = LogTarget(dayTitle: day.title, loggable: loggable)
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if idx < day.lines.count - 1 { Divider() }
            }
        }
        .squareCard()
    }
}
