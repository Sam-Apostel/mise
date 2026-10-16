import SwiftUI
import MiseShared

/// From the camera's "Who's eating" capsule: the people at the table.
struct WhoIsEatingSheet: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Who's eating").font(.boardName).boardCaps()
                .padding(.horizontal, Board.margin).padding(.top, 22).padding(.bottom, 8)
            List {
                ForEach(model.profiles) { profile in
                    Button { editing = profile } label: { row(profile) }
                        .listRowBackground(Board.raised)
                }
                Button { editing = Profile(name: "") } label: {
                    Label("Add a person", systemImage: "plus").font(.boardBody).foregroundStyle(Board.paint)
                }
                .listRowBackground(Board.raised)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .foregroundStyle(Board.onRaised)
        .background(Board.raised)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Board.cardRadius)
        .presentationBackground(Board.raised)
        .environment(\.colorScheme, .light)
        .sheet(item: $editing) { PeopleSheet(profile: $0) }
    }

    private func row(_ profile: Profile) -> some View {
        HStack(spacing: 12) {
            Text(profile.initial).font(.boardHeavy(17)).foregroundStyle(Board.raised)
                .frame(width: 40, height: 40).background(Board.paint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.system(size: 17, weight: .semibold))
                Text(summary(profile)).font(.boardMeta).foregroundStyle(Board.onRaised2).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Board.onRaised2)
        }
        .padding(.vertical, 4)
    }

    private func summary(_ p: Profile) -> String {
        var parts = Allergen.allCases.filter(p.allergens.contains).map(\.displayName)
        parts += p.avoids.map { "no \($0)" }
        if p.maxSpice < .hot { parts.append("up to \(p.maxSpice.displayName.lowercased())") }
        return parts.isEmpty ? "Eats anything" : parts.joined(separator: " · ")
    }
}

/// The gear: home currency and where things come from.
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Prices") {
                    Picker("Home currency", selection: $model.homeCurrency) {
                        ForEach(["EUR", "USD", "GBP", "THB"], id: \.self) { Text($0) }
                    }
                }
                Section("About") {
                    LabeledContent("Photos", value: "Wikimedia Commons, Pexels, Pixabay")
                    LabeledContent("Rates", value: "European Central Bank via Frankfurter")
                    LabeledContent("Type", value: "Bricolage Grotesque, SIL OFL 1.1")
                }
                Section {
                    Button("Clear recent menus", role: .destructive) { model.recents = [] }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
