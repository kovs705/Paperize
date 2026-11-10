import Paperize
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { JournalView() }
                .tabItem { Label("Journal", systemImage: "book.closed") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Paper", systemImage: "doc.plaintext") }
        }
    }
}

// MARK: - Journal

struct JournalView: View {
    @State private var page = 0
    private let habits = [
        Habit(name: "Stretch", symbol: "figure.flexibility", streak: 10, best: 10, week: 7, total: 108),
        Habit(name: "Read", symbol: "book", streak: 4, best: 21, week: 5, total: 212),
        Habit(name: "Walk", symbol: "figure.walk", streak: 2, best: 14, week: 3, total: 64),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                DotHistory(seed: page)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Current Streak", value: "\(habit.streak)", caption: "days")
                    StatCard(title: "Top Streak", value: "\(habit.best)", caption: "days")
                    StatCard(title: "This Week", value: "\(habit.week)", caption: "of 7")
                    StatCard(title: "Total Reps", value: "\(habit.total)", caption: "all time")
                }
                NavigationLink {
                    DetailView(habit: habit)
                } label: {
                    HStack {
                        Text("See full details")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { page = (page + habits.count - 1) % habits.count } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text("Page \(page + 1) of \(habits.count)").font(.footnote)
                Spacer()
                Button { page = (page + 1) % habits.count } label: { Image(systemName: "chevron.right") }
            }
        }
        // Each page turn plays an e-ink refresh.
        .paperizeRefresh(on: page)
    }

    private var habit: Habit { habits[page] }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 56, height: 56)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading) {
                Text(habit.name).font(.title.bold())
                Text("Level \(min(habit.streak, 8)) of 8").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct Habit {
    let name: String
    let symbol: String
    let streak: Int
    let best: Int
    let week: Int
    let total: Int
}

struct StatCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(.system(size: 44, weight: .bold, design: .rounded))
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct DotHistory: View {
    let seed: Int

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 21)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<(21 * 6), id: \.self) { index in
                Circle()
                    .fill(isDone(index) ? Color.green : Color.gray.opacity(0.25))
                    .frame(width: 9, height: 9)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func isDone(_ index: Int) -> Bool {
        (index &* 2_654_435_761 &+ seed &* 97) % 7 < 4
    }
}

struct DetailView: View {
    let habit: Habit
    @State private var showsAlert = false

    var body: some View {
        List {
            Section("Photo") {
                // Colorful content shows off the grayscale effect.
                LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 120)
                    .listRowInsets(EdgeInsets())
            }
            Section("Stats") {
                LabeledContent("Current streak", value: "\(habit.streak)")
                LabeledContent("Top streak", value: "\(habit.best)")
                LabeledContent("Total reps", value: "\(habit.total)")
            }
            Section {
                Button("Show an alert") { showsAlert = true }
                Button("Full refresh") { Paperize.refresh(.full) }
                Button("Partial refresh") { Paperize.refresh(.partial) }
            }
        }
        .navigationTitle(habit.name)
        .alert("Alerts are paper too", isPresented: $showsAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}
