import SwiftUI
import MiseShared

/// One dish: the photo leads, then what it means for each person at the table,
/// what is in it, and what it is.
struct DishView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let dish: Dish
    let showPicks: () -> Void
    @State private var askingWaiter = false
    @State private var added = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Board.ground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    titleBlock
                        .padding(.top, 12)
                    if !model.profiles.isEmpty || model.filter.isActive { forTheTable }
                    contains
                    whatItIs
                }
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            topBar
                .frame(maxHeight: .infinity, alignment: .top)
            BottomFade().ignoresSafeArea(edges: .bottom)
            bottomBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $askingWaiter) { WaiterCardView(mode: .ask(dish)) }
        .sensoryFeedback(.success, trigger: added)
    }

    // MARK: Hero

    private var hero: some View {
        Color.clear
            .frame(height: 330)
            .frame(maxWidth: .infinity)
            .overlay { DishPhoto(dish: dish, plateScale: 0.6) }
            .clipped()
            .overlay(alignment: .top) {
                LinearGradient(colors: [Color(hex: 0x05140C, alpha: 0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 130)
            }
            .overlay(alignment: .bottomLeading) {
                NumberChip(text: chip, leading: 20)
                    .padding(.bottom, -1)
            }
    }

    private var chip: String {
        let price = dish.price.map { model.price($0, currency: dish.currency) }
        return [dish.menuNumber, price].compactMap { $0 }.joined(separator: " · ")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dish.imageURL != nil {
                Text(["Typical photo, not this kitchen's.", dish.imageCredit.map { $0 + "." }]
                        .compactMap { $0 }.joined(separator: " "))
                    .font(.boardMeta).tracking(0.2)
                    .foregroundStyle(Board.ink3)
                    .padding(.bottom, 8)
            }
            Text(title)
                .font(.boardDisplay).boardCaps(tracking: -0.5)
                .foregroundStyle(Board.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.boardBody).tracking(-0.4)
                    .foregroundStyle(Board.ink2)
                    .padding(.top, 4)
            }
            if let price = dish.price {
                HStack(spacing: 0) {
                    Text(model.price(price, currency: dish.currency)).fontWeight(.semibold)
                    if let home = model.homePrice(price) {
                        Text(" · \(home)").foregroundStyle(Board.ink3)
                    }
                }
                .font(.boardBody).monospacedDigit()
                .foregroundStyle(Board.ink)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, Board.margin)
    }

    private var latin: Bool { !(model.menu?.isNonLatinScript ?? false) }
    private var title: String { latin ? (dish.originalName ?? dish.name) : dish.name }
    private var subtitle: String? { latin ? (dish.originalName == nil ? nil : dish.name) : dish.originalName }

    // MARK: For the table

    private var forTheTable: some View {
        block("For the table") {
            VStack(spacing: 0) {
                let people: [Profile?] = model.profiles.isEmpty ? [nil] : model.profiles
                ForEach(Array(people.enumerated()), id: \.offset) { index, profile in
                    if index > 0 { Rectangle().fill(Board.rule).frame(height: 1) }
                    verdictRow(profile)
                }
            }
        }
    }

    private func verdictRow(_ profile: Profile?) -> some View {
        let verdict = model.verdict(for: dish, profile: profile)
        let color: Color = switch verdict.kind {
        case .fine: Board.ink
        case .ask: Board.ask
        case .no: Board.no
        }
        return HStack(alignment: .top, spacing: 12) {
            Text(profile?.initial ?? "∞")
                .font(.boardHeavy(15))
                .foregroundStyle(verdict.kind == .fine ? Board.ink : color)
                .frame(width: 36, height: 36)
                .overlay { Circle().strokeBorder(verdict.kind == .fine ? Board.rule : color, lineWidth: 1.5) }
            VStack(alignment: .leading, spacing: 1) {
                Text(sentence(verdict, profile: profile))
                    .font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    .foregroundStyle(color)
                detail(verdict)
                    .font(.boardSecondary)
                    .foregroundStyle(Board.ink2)
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func sentence(_ verdict: Verdict, profile: Profile?) -> String {
        let name = profile?.name ?? "Tonight"
        let pronoun = switch profile?.speech {
        case .feminine: "she keeps"
        case .masculine: "he keeps"
        default: "they keep"
        }
        switch (verdict.kind, verdict.cause) {
        case (.fine, _):
            return profile.map { "Fine for \($0.name)." } ?? "Fine tonight."
        case (.ask, .likely(let likely)?):
            if let note = likely.note { return "\(name): \(note.lowercased().capitalizedFirst). Ask." }
            return "\(name): usually has \(likely.name). Ask."
        case (.no, .spice(let level, let max)?):
            return "Not for \(name): \(level.displayName.lowercased()), \(pronoun) to \(max.displayName.lowercased())."
        case (.no, _):
            return "Not for \(name): \((verdict.reason ?? "").lowercased())."
        default:
            return "\(name): \(verdict.reason ?? "")"
        }
    }

    @ViewBuilder
    private func detail(_ verdict: Verdict) -> some View {
        switch verdict.cause {
        case .likely(let likely)?:
            if let question = likely.question {
                Text([question, likely.questionTranslation.map { "\"\($0)\"" }].compactMap { $0 }
                        .joined(separator: " · "))
            }
        case .spice(let level, _)?:
            HStack(spacing: 6) {
                Chilis(count: level.level)
                Text("on this menu's scale")
            }
        default:
            EmptyView()
        }
    }

    // MARK: Contains, what it is

    @ViewBuilder
    private var contains: some View {
        if !dish.ingredients.isEmpty || !dish.likelyIngredients.isEmpty {
            block("Contains") {
                (Text(dish.ingredients.isEmpty ? "" : listed + ". ")
                 + Text(probably).foregroundStyle(Board.ink2))
                    .font(.boardSecondary).tracking(-0.2)
                    .foregroundStyle(Board.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var listed: String {
        dish.ingredients.joined(separator: ", ").capitalizedFirst
    }

    private var probably: String {
        guard !dish.likelyIngredients.isEmpty else { return "" }
        return "Probably " + dish.likelyIngredients.map(\.name).joined(separator: ", ") + "."
    }

    @ViewBuilder
    private var whatItIs: some View {
        if dish.description != nil || dish.originalDescription != nil {
            block("What it is") {
                VStack(alignment: .leading, spacing: 8) {
                    if let original = dish.originalDescription {
                        Text("\(original) · from the menu")
                            .font(.boardSecondary).foregroundStyle(Board.ink3)
                    }
                    if let description = dish.description {
                        Text(description).font(.boardBody).tracking(-0.4).foregroundStyle(Board.ink)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).boardLabelStyle().foregroundStyle(Board.ink2)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Board.margin)
        .padding(.top, 22)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            GlassCircleButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            Spacer()
            GlassCapsuleButton(systemImage: "bookmark",
                               title: model.pickCount > 0 ? "Picks · \(model.pickCount)" : "Picks") {
                dismiss()
                showPicks()
            }
        }
        .padding(.horizontal, 16)
    }

    private var bottomBar: some View {
        let quantity = model.quantity(of: dish)
        return HStack(spacing: 10) {
            if askable {
                BoardCTA(title: "Ask the waiter", style: .outline) { askingWaiter = true }
            }
            BoardCTA(title: quantity == 0 ? "Add to picks" : "Added · \(quantity)",
                     systemImage: quantity == 0 ? "plus" : "checkmark") {
                withAnimation(.snappy) { model.add(dish) }
                added += 1
            }
        }
        .padding(.horizontal, Board.margin)
        .padding(.bottom, 8)
    }

    private var askable: Bool {
        dish.likelyIngredients.contains { $0.question != nil }
    }
}
