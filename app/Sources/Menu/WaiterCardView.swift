import SwiftUI
import UIKit
import MiseShared

/// The output: a cream card you turn to the waiter. Dish names in the menu's
/// script led by their menu number, the allergy sentence in red, thank you.
struct WaiterCardView: View {
    enum Mode { case order, ask(Dish) }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    @State private var english = false
    @State private var bright = false
    @State private var savedBrightness: CGFloat?
    @State private var remote: PhraseSet?

    var body: some View {
        ZStack {
            Board.ground.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                ScrollView {
                    card
                        .padding(.horizontal, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                Text(english ? "Tap to flip back" : "Tap to flip to English")
                    .font(.boardSecondary).foregroundStyle(Board.ink2)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
            .onTapGesture { withAnimation(.smooth) { english.toggle() } }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                GlassCircleButton(systemImage: "xmark", label: "Close") { dismiss() }
                Spacer()
                GlassCapsuleButton(systemImage: bright ? "sun.max.fill" : "sun.max", title: "Bright") {
                    setBright(!bright)
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear { setBright(true) }
        .onDisappear { setBright(false) }
        .task { await fetchRemotePhrasesIfNeeded() }
    }

    private var profile: Profile? { model.selectedProfile }
    private var phrases: PhraseSet { remote ?? model.phrases(for: profile) }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            who
            switch mode {
            case .order:
                ForEach(model.pickedDishes, id: \.dish.id) { line in
                    orderLine(line.dish, quantity: line.quantity)
                }
            case .ask(let dish):
                askLines(dish)
            }
            if !phrases.allergy.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if english {
                        Text(phrases.allergyTranslation ?? "").font(.system(size: 28, weight: .heavy)).tracking(-0.6)
                    } else {
                        ForEach(phrases.allergy, id: \.self) { line in
                            Text(line).font(.system(size: 34, weight: .heavy)).tracking(-0.6)
                        }
                        if let translation = phrases.allergyTranslation {
                            Text(translation).font(.boardSecondary)
                        }
                    }
                }
                .foregroundStyle(Board.noDeep)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Board.onRaised.opacity(0.15)).frame(height: 1.5) }
                .padding(.top, 8)
            }
            HStack(spacing: 0) {
                Text(english ? "Thank you" : phrases.thanks).fontWeight(.heavy)
                if !english { Text(" · thank you").foregroundStyle(Board.onRaised2) }
            }
            .font(.boardBody)
            .padding(.top, 6)
        }
        .foregroundStyle(Board.onRaised)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Board.raised, in: .rect(cornerRadius: Board.cardRadius))
        .environment(\.colorScheme, .light)
    }

    private var who: some View {
        HStack(spacing: 10) {
            Text(profile?.initial ?? "∞").font(.boardHeavy(14))
                .frame(width: 32, height: 32)
                .overlay { Circle().strokeBorder(Board.onRaised, lineWidth: 2) }
            Text(whoLine).font(.boardSecondary).foregroundStyle(Board.onRaised2)
        }
    }

    private var whoLine: String {
        let name = profile.map { "Order for \($0.name)" } ?? "Order for the table"
        if case .ask = mode { return profile.map { "A question from \($0.name)" } ?? "A question" }
        return english ? name : "\(name) · \(phrases.order)"
    }

    private func orderLine(_ dish: Dish, quantity: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let number = dish.menuNumber {
                    Text(number).font(.boardHeavy(20)).foregroundStyle(Board.onRaised2)
                }
                Text(english ? dish.name : (dish.originalName ?? dish.name))
                    .font(.system(size: 34, weight: .heavy)).tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(english ? "×\(quantity)" : "×\(quantity) · \(dish.name)")
                .font(.boardSecondary).foregroundStyle(Board.onRaised2)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func askLines(_ dish: Dish) -> some View {
        orderLine(dish, quantity: max(1, model.quantity(of: dish)))
        ForEach(dish.likelyIngredients.filter { $0.question != nil }, id: \.name) { likely in
            VStack(alignment: .leading, spacing: 2) {
                Text(english ? (likely.questionTranslation ?? likely.name) : likely.question!)
                    .font(.system(size: 34, weight: .heavy)).tracking(-0.6)
                if !english, let translation = likely.questionTranslation {
                    Text(translation).font(.boardSecondary).foregroundStyle(Board.onRaised2)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Behaviour

    private func setBright(_ on: Bool) {
        bright = on
        guard let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen else { return }
        if on {
            if savedBrightness == nil { savedBrightness = screen.brightness }
            screen.brightness = 1
        } else if let saved = savedBrightness {
            screen.brightness = saved
            savedBrightness = nil
        }
    }

    /// Languages PhraseBook does not carry come from the server, when it is reachable.
    private func fetchRemotePhrasesIfNeeded() async {
        guard let language = model.menu?.sourceLanguage,
              !PhraseBook.languages.contains(String(language.prefix(2))) else { return }
        let severe = profile.map { $0.severe ? [$0] : [] } ?? model.profiles.filter(\.severe)
        let allergens = Allergen.allCases.filter { a in severe.contains { $0.allergens.contains(a) } }
        remote = try? await APIClient().phrases(
            PhrasesRequest(language: language, allergens: allergens, speech: profile?.speech ?? .neutral))
    }
}
