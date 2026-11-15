import SwiftUI
import WidgetKit

struct PetEntry: TimelineEntry {
    let date: Date
    let status: PetStatus?
}

struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: .now, status: PetSnapshot.example.projected(at: Date(timeIntervalSince1970: 0)))
    }
    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }
    private func entry(at date: Date) -> PetEntry {
        let snapshot = PetWidgetConfig.sharedURL.flatMap { PetSnapshot.read(from: $0) }
        return PetEntry(date: date, status: snapshot?.projected(at: date))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let now = Date()
        guard let url = PetWidgetConfig.sharedURL, let snapshot = PetSnapshot.read(from: url) else {
            completion(Timeline(entries: [PetEntry(date: now, status: nil)], policy: .after(now.addingTimeInterval(1800))))
            return
        }
        // Always project from the original save; repeated reloads must not extend
        // the game's eight-hour offline cap or repeatedly apply the same decay.
        let entries = (0...32).map { index -> PetEntry in
            let date = now.addingTimeInterval(Double(index) * 900)
            return PetEntry(date: date, status: snapshot.projected(at: date))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(8 * 3600))))
    }
}

struct PetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetEntry

    private let ink = Color(red: 0.24, green: 0.19, blue: 0.15)
    private let paper = Color(red: 0.98, green: 0.95, blue: 0.88)

    var body: some View {
        Group {
            if let status = entry.status {
                if family == .accessoryRectangular { accessory(status) }
                else if family == .systemMedium { medium(status) }
                else { small(status) }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("YuFriend", systemImage: "pawprint.fill").font(.headline)
                    Text("Otwórz grę, aby poznać swojego pieska.").font(.caption)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(family == .accessoryRectangular ? Color.primary : ink)
        .modifier(PetWidgetBackground(color: paper))
    }

    private func portrait(_ status: PetStatus) -> some View {
        Image(uiImage: UIImage(named: status.resting ? "puppy-sleep" : "puppy-idle") ?? UIImage())
            .resizable().interpolation(.none).scaledToFit()
            .accessibilityHidden(true)
    }
    private func small(_ status: PetStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.snapshot.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Text(status.resting ? "Odpoczywa" : "Twój przyjaciel").font(.caption2)
                }
                Spacer(minLength: 0)
                Image(systemName: status.resting ? "moon.zzz.fill" : "pawprint.fill").foregroundStyle(.secondary)
            }
            portrait(status).frame(maxWidth: .infinity).frame(height: 52)
            Text(status.headline).font(.caption.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
            if let need = status.priorities.first, !status.stale {
                HStack {
                    Label(need.title, systemImage: need.symbol)
                    Spacer(minLength: 2)
                    Text("\(Int(status.value(need).rounded()))%")
                }.font(.caption2).foregroundStyle(tint(status.value(need)))
            } else {
                Text("Otwórz grę, by odświeżyć").font(.caption2)
            }
        }
    }
    private func medium(_ status: PetStatus) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(status.snapshot.name).font(.headline).lineLimit(1).minimumScaleFactor(0.65)
                Text(status.moodLabel).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                portrait(status).frame(maxWidth: .infinity).frame(height: 48)
                Text(status.headline).font(.caption.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
                if status.stale {
                    Text("Odśwież w grze").font(.caption2).foregroundStyle(.secondary)
                } else if status.urgentNeeds.count > 1 {
                    Text(status.urgentNeeds[1].suggestion).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
                }
            }.frame(maxWidth: .infinity)
            VStack(spacing: 5) {
                ForEach(PetNeed.allCases, id: \.self) { need in
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: need.symbol).frame(width: 12)
                            Text(need.title)
                            Spacer(minLength: 0)
                            Text("\(Int(status.value(need).rounded()))%")
                                .monospacedDigit()
                        }.font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ink.opacity(0.09))
                                Capsule().fill(tint(status.value(need)))
                                    .frame(width: max(2, proxy.size.width * status.value(need) / 100))
                            }
                        }.frame(height: 3)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(need.title), \(Int(status.value(need).rounded())) procent")
                }
                Text(status.stale ? "Zapis sprzed ponad 8 h" : "Stan szacowany")
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity)
        }
    }
    private func accessory(_ status: PetStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(status.snapshot.name, systemImage: status.resting ? "moon.zzz.fill" : "pawprint.fill")
                .font(.headline).lineLimit(1)
            Text(status.headline).font(.caption).lineLimit(1)
            if let need = status.priorities.first, !status.stale {
                Text("\(need.title) · \(Int(status.value(need).rounded()))%")
                    .font(.caption2)
            }
        }
    }
    private func tint(_ value: Double) -> Color {
        value < 30 ? Color(red: 0.67, green: 0.23, blue: 0.16) :
        value < 60 ? Color(red: 0.53, green: 0.35, blue: 0.09) :
        Color(red: 0.24, green: 0.43, blue: 0.31)
    }
}

private struct PetWidgetBackground: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { color }
        } else {
            content.padding().background(color)
        }
    }
}

@main
struct YuFriendPetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PetWidgetConfig.kind, provider: PetProvider()) { entry in
            PetWidgetView(entry: entry)
        }
        .configurationDisplayName("Twój piesek")
        .description("Sprawdź, jak czuje się Twój przyjaciel i czego teraz potrzebuje.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
