import SwiftUI
import WidgetKit

// MARK: - App Group storage

enum AppGroupUserDefaults {
    static let groupSuiteName = "group.com.meditatorapp.meditator"

    private enum Keys {
        static let streakCount = "widget_streak_count"
        static let dailyQuote = "widget_daily_quote"
        static let totalMinutes = "widget_total_minutes"
    }

    static var shared: UserDefaults? {
        UserDefaults(suiteName: groupSuiteName)
    }

    static func readStreak() -> Int {
        guard let ud = shared else { return 0 }
        if ud.object(forKey: Keys.streakCount) != nil {
            return ud.integer(forKey: Keys.streakCount)
        }
        return 0
    }

    static func readQuote() -> String {
        guard let ud = shared else { return defaultQuote }
        return ud.string(forKey: Keys.dailyQuote).flatMap { $0.isEmpty ? nil : $0 } ?? defaultQuote
    }

    static func readTotalMinutes() -> Int {
        guard let ud = shared else { return 0 }
        if ud.object(forKey: Keys.totalMinutes) != nil {
            return ud.integer(forKey: Keys.totalMinutes)
        }
        return 0
    }

    private static let defaultQuote = "Тишина — это тоже практика."

    static func loadEntry(date: Date) -> MeditatorEntry {
        MeditatorEntry(
            date: date,
            streakCount: readStreak(),
            dailyQuote: readQuote(),
            totalMinutes: readTotalMinutes()
        )
    }
}

// MARK: - Entry

struct MeditatorEntry: TimelineEntry {
    let date: Date
    let streakCount: Int
    let dailyQuote: String
    let totalMinutes: Int
}

// MARK: - Timeline

struct MeditatorProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeditatorEntry {
        MeditatorEntry(
            date: Date(),
            streakCount: 7,
            dailyQuote: "Каждый вдох — новое начало.",
            totalMinutes: 120
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MeditatorEntry) -> Void) {
        completion(AppGroupUserDefaults.loadEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeditatorEntry>) -> Void) {
        let entry = AppGroupUserDefaults.loadEntry(date: Date())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Design tokens

private extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hexSanitized.count == 6 { hexSanitized.append("FF") }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb >> 24) & 0xFF) / 255
        let g = Double((rgb >> 16) & 0xFF) / 255
        let b = Double((rgb >> 8) & 0xFF) / 255
        let a = Double(rgb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

private enum Theme {
    static let void = Color(hex: "#020617")
    static let deep = Color(hex: "#0F172A")
    static let accent = Color(hex: "#818CF8")
    static let accentSoft = Color(hex: "#818CF8").opacity(0.35)
    static let text = Color.white
    static let textMuted = Color.white.opacity(0.72)

    static let playURL = URL(string: "meditator://play")!
}

private func russianStreakLine(days: Int) -> String {
    "Серия: \(russianDays(days))"
}

private func russianDays(_ n: Int) -> String {
    let n10 = n % 10
    let n100 = n % 100
    if n100 >= 11, n100 <= 14 { return "\(n) дней" }
    switch n10 {
    case 1: return "\(n) день"
    case 2, 3, 4: return "\(n) дня"
    default: return "\(n) дней"
    }
}

private func russianTotalMinutes(_ m: Int) -> String {
    "Всего: \(m) мин"
}

// MARK: - Background

private struct SpaceGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.void, Theme.deep, Theme.void.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.accentSoft.opacity(0.55), Color.clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 160
            )
            RadialGradient(
                colors: [Theme.accent.opacity(0.12), Color.clear],
                center: .bottomLeading,
                startRadius: 2,
                endRadius: 140
            )
        }
    }
}

private struct GlowOrb: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.accent.opacity(0.45), Theme.accent.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 36
                )
            )
            .frame(width: 72, height: 72)
            .blur(radius: 8)
    }
}

// MARK: - Views

private struct SmallMeditatorView: View {
    let entry: MeditatorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 22))
                Text("\(entry.streakCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }
            Text(russianStreakLine(days: entry.streakCount))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textMuted)
            Spacer(minLength: 0)
            Text("Meditator")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct MediumMeditatorView: View {
    let entry: MeditatorEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 20))
                    Text("\(entry.streakCount)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                }
                Text(russianStreakLine(days: entry.streakCount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                Spacer(minLength: 0)
                Text("Meditator")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Сегодня")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                Text(entry.dailyQuote)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Link(destination: Theme.playURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Начать медитацию")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.void)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

private struct LargeMeditatorView: View {
    let entry: MeditatorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meditator")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text("Ежедневная практика")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                ZStack {
                    GlowOrb()
                    Text("🔥")
                        .font(.system(size: 28))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(entry.streakCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text(russianStreakLine(days: entry.streakCount))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
            }

            Text(entry.dailyQuote)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text.opacity(0.95))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)

            Text(russianTotalMinutes(entry.totalMinutes))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textMuted)

            Spacer(minLength: 0)

            Link(destination: Theme.playURL) {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Начать медитацию")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: Theme.accent.opacity(0.5), radius: 16, y: 8)
                )
                .foregroundStyle(Theme.void)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
    }
}

struct MeditatorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MeditatorEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallMeditatorView(entry: entry)
            case .systemMedium:
                MediumMeditatorView(entry: entry)
            case .systemLarge:
                LargeMeditatorView(entry: entry)
            default:
                SmallMeditatorView(entry: entry)
            }
        }
        .widgetURL(Theme.playURL)
    }
}

// MARK: - Widget

struct MeditatorWidget: Widget {
    let kind: String = "MeditatorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeditatorProvider()) { entry in
            MeditatorWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        SpaceGradientBackground()
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Theme.accent.opacity(0.25),
                                        Color.white.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(1)
                    }
                }
        }
        .configurationDisplayName("Meditator")
        .description("Серия, цитата дня и быстрый старт медитации.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    MeditatorWidget()
} timeline: {
    MeditatorEntry(date: .now, streakCount: 5, dailyQuote: "Дыши глубже.", totalMinutes: 84)
}

#Preview(as: .systemMedium) {
    MeditatorWidget()
} timeline: {
    MeditatorEntry(date: .now, streakCount: 12, dailyQuote: "Спокойствие — навык, который можно тренировать.", totalMinutes: 240)
}

#Preview(as: .systemLarge) {
    MeditatorWidget()
} timeline: {
    MeditatorEntry(date: .now, streakCount: 30, dailyQuote: "Маленькие шаги каждый день меняют всё.", totalMinutes: 512)
}
