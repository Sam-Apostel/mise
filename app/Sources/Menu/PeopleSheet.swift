import SwiftUI
import MiseShared

/// One person's fixed profile: allergies (red), what they just don't eat,
/// their spice ceiling, and the sentence the waiter will hear.
struct PeopleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Profile
    @State private var addingOther = false
    @State private var otherAvoid = ""
    @FocusState private var nameFocused: Bool

    init(profile: Profile) {
        _draft = State(initialValue: profile)
    }

    private var isNew: Bool { !model.profiles.contains { $0.id == draft.id } }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    allergies
                    avoids
                    VStack(alignment: .leading, spacing: 0) {
                        CreamGroupHeader(title: "Spice, up to")
                        SpiceSegments(firstTitle: "None", level: spiceBinding)
                    }
                    waiterHears
                    if !isNew {
                        Button("Remove \(draft.name)", role: .destructive) {
                            model.delete(draft)
                            dismiss()
                        }
                        .font(.boardBody)
                        .tint(Board.noDeep)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Board.margin)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .background(Board.raised)
        .presentationDetents([.fraction(0.86), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Board.cardRadius)
        .presentationBackground(Board.raised)
        .environment(\.colorScheme, .light)
        .onAppear { if isNew { nameFocused = true } }
        .alert("Doesn't eat", isPresented: $addingOther) {
            TextField("An ingredient", text: $otherAvoid)
            Button("Add") {
                let word = otherAvoid.trimmingCharacters(in: .whitespaces).lowercased()
                if !word.isEmpty, !draft.avoids.contains(word) { draft.avoids.append(word) }
                otherAvoid = ""
            }
            Button("Cancel", role: .cancel) { otherAvoid = "" }
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 12) {
            Text(draft.initial).font(.boardHeavy(20))
                .foregroundStyle(Board.raised)
                .frame(width: 52, height: 52)
                .background(Board.paint, in: Circle())
            TextField("Name", text: $draft.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Board.onRaised)
                .focused($nameFocused)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Board.onRaised.opacity(0.06), in: .rect(cornerRadius: 10))
            Button("Done") { save() }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Board.paint)
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.leading, 4)
        }
        .padding(.horizontal, Board.margin)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var allergies: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreamGroupHeader(title: "Allergic to")
            FlowLayout(spacing: 8) {
                ForEach(Self.allergenOrder, id: \.self) { allergen in
                    CreamChip(title: allergen.displayName,
                              detail: allergen == .shellfish ? "shrimp, crab" : nil,
                              isOn: draft.allergens.contains(allergen), onColor: Board.noDeep) {
                        withAnimation(.snappy) {
                            if draft.allergens.contains(allergen) { draft.allergens.remove(allergen) }
                            else { draft.allergens.insert(allergen) }
                        }
                    }
                }
            }
            HStack {
                Text("Severe: put it on the waiter card").font(.boardSecondary).foregroundStyle(Board.onRaised)
                Spacer()
                Toggle("", isOn: $draft.severe).labelsHidden().tint(Board.paint)
            }
            .frame(minHeight: 44)
            .padding(.top, 8)
        }
    }

    static let allergenOrder: [Allergen] = [.peanuts, .shellfish, .nuts, .sesame, .gluten, .dairy, .egg, .fish, .soy]

    private var avoids: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreamGroupHeader(title: "Avoids", detail: "not allergic, just doesn't eat")
            FlowLayout(spacing: 8) {
                let options = Profile.commonAvoids + draft.avoids.filter { !Profile.commonAvoids.contains($0) }
                ForEach(options, id: \.self) { word in
                    CreamChip(title: word.capitalizedFirst, isOn: draft.avoids.contains(word)) {
                        withAnimation(.snappy) {
                            if let i = draft.avoids.firstIndex(of: word) { draft.avoids.remove(at: i) }
                            else { draft.avoids.append(word) }
                        }
                    }
                }
                CreamChip(title: "+ other", isOn: false) { addingOther = true }
            }
        }
    }

    private var spiceBinding: Binding<SpiceLevel?> {
        Binding(get: { draft.maxSpice == .none ? nil : draft.maxSpice },
                set: { draft.maxSpice = $0 ?? .none })
    }

    /// The sentence previewed in the languages of recent menus (and the current one).
    private var waiterHears: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreamGroupHeader(title: "What the waiter hears")
            if draft.allergens.isEmpty {
                Text("Nothing yet. Add an allergy and the waiter card will say it in the menu's language.")
                    .font(.boardSecondary).foregroundStyle(Board.onRaised2)
            }
            ForEach(Array(languages.enumerated()), id: \.element) { index, language in
                if let set = PhraseBook.phrases(language: language, allergens: draft.allergens, speech: draft.speech),
                   !set.allergy.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Locale.current.localizedString(forLanguageCode: language) ?? language)
                            .font(.boardMeta).foregroundStyle(Board.onRaised2)
                        Text(set.allergy.joined(separator: " "))
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Board.noDeep)
                            .fixedSize(horizontal: false, vertical: true)
                        if let translation = set.allergyTranslation {
                            Text(translation).font(.boardMeta).foregroundStyle(Board.onRaised2)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        if index > 0 { Rectangle().fill(Board.raisedRule).frame(height: 1) }
                    }
                }
            }
        }
    }

    private var languages: [String] {
        var result: [String] = []
        for menu in [model.menu].compactMap({ $0 }) + model.recents {
            if let language = menu.sourceLanguage.map({ String($0.prefix(2)) }),
               PhraseBook.languages.contains(language), language != "en", !result.contains(language) {
                result.append(language)
            }
        }
        return result.isEmpty ? ["th", "it"] : result
    }

    @ViewBuilder
    private var footer: some View {
        if let menu = model.menu {
            let verdicts = menu.dishes.map { Verdict.for($0, profile: draft, filter: model.filter).kind }
            let fine = verdicts.filter { $0 == .fine }.count
            let ask = verdicts.filter { $0 == .ask }.count
            let no = verdicts.filter { $0 == .no }.count
            (Text("At \(menu.restaurantName ?? "this menu"): ")
             + Text("\(fine) fine").foregroundStyle(Board.onRaised).fontWeight(.semibold)
             + Text(" · \(ask) ask · \(no) no"))
                .font(.boardSecondary)
                .foregroundStyle(Board.onRaised2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Board.margin)
                .padding(.vertical, 16)
                .background(alignment: .bottom) { BottomFade(color: Board.raised, height: 90).ignoresSafeArea() }
        }
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        model.upsert(draft)
        if isNewSelection { model.selectedProfileID = draft.id }
        dismiss()
    }

    private var isNewSelection: Bool { model.profiles.count == 1 }
}
