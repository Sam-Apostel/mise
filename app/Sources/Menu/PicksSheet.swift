import SwiftUI
import MiseShared

/// Picks, for the table: quantities, a total in both currencies, a check that
/// nothing on the list is crossed out for the selected person, and the way to the waiter.
struct PicksSheet: View {
    @Environment(AppModel.self) private var model
    let showWaiter: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Picks").font(.boardName).boardCaps()
                Spacer()
                Text("for the table · \(itemsLabel)").font(.boardSecondary).foregroundStyle(Board.onRaised2)
            }
            .foregroundStyle(Board.onRaised)
            .padding(.horizontal, Board.margin)
            .padding(.top, 22)
            .padding(.bottom, 6)

            if model.picks.isEmpty {
                empty
            } else {
                List {
                    ForEach(model.pickedDishes, id: \.dish.id) { line in
                        row(line.dish, quantity: line.quantity)
                            .listRowInsets(EdgeInsets(top: 10, leading: Board.margin, bottom: 10, trailing: Board.margin))
                            .listRowBackground(Board.raised)
                            .listRowSeparatorTint(Board.raisedRule)
                            .swipeActions(edge: .trailing) {
                                Button("Remove") { withAnimation { model.remove(line.dish.id) } }
                                    .tint(Board.paint)
                            }
                    }
                    totals
                        .listRowInsets(EdgeInsets(top: 14, leading: Board.margin, bottom: 0, trailing: Board.margin))
                        .listRowBackground(Board.raised)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !model.picks.isEmpty {
                BoardCTA(title: "Show the waiter", systemImage: "list.bullet.rectangle.portrait", style: .paint) {
                    showWaiter()
                }
                .padding(.horizontal, Board.margin)
                .padding(.bottom, 8)
                .background(alignment: .bottom) { BottomFade(color: Board.raised, height: 100).ignoresSafeArea() }
            }
        }
        .background(Board.raised)
        .presentationDetents([.fraction(0.64), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Board.cardRadius)
        .presentationBackground(Board.raised)
        .environment(\.colorScheme, .light)
    }

    private var itemsLabel: String {
        model.pickCount == 1 ? "1 item" : "\(model.pickCount) items"
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Nothing picked yet").font(.boardName).boardCaps().foregroundStyle(Board.onRaised)
            Text("Open a dish and tap Add to picks. The waiter card is made from this list.")
                .font(.boardSecondary).foregroundStyle(Board.onRaised2).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ dish: Dish, quantity: Int) -> some View {
        HStack(spacing: 12) {
            DishPhoto(dish: dish, plateScale: 0.9)
                .frame(width: 64, height: 48)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .bottomLeading) {
                    if let number = dish.menuNumber {
                        Text(number).font(.boardHeavy(13)).foregroundStyle(Board.onRaised)
                            .padding(.horizontal, 5).padding(.top, 3).padding(.bottom, 2)
                            .background(Board.raised, in: UnevenRoundedRectangle(topTrailingRadius: 6))
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(dish.name).font(.system(size: 17, weight: .semibold)).tracking(-0.4)
                    .foregroundStyle(Board.onRaised).lineLimit(1)
                Text([dish.originalName, dish.price.map { model.price($0 * Decimal(quantity), currency: dish.currency) }]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.boardMeta).monospacedDigit()
                    .foregroundStyle(Board.onRaised2).lineLimit(1)
            }
            Spacer(minLength: 4)
            stepper(dish, quantity: quantity)
        }
    }

    private func stepper(_ dish: Dish, quantity: Int) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { model.decrement(dish) }
            } label: {
                Image(systemName: quantity == 1 ? "xmark" : "minus").font(.system(size: 13, weight: .medium))
                    .frame(width: 32, height: 40).contentShape(.rect)
            }
            .accessibilityLabel(quantity == 1 ? "Remove \(dish.name)" : "One fewer")
            Text("\(quantity)").font(.boardHeavy(17)).frame(width: 30)
                .contentTransition(.numericText(value: Double(quantity)))
            Button {
                withAnimation(.snappy) { model.add(dish) }
            } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                    .frame(width: 32, height: 40).contentShape(.rect)
            }
            .accessibilityLabel("One more")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Board.onRaised)
        .padding(.horizontal, 4)
        .frame(height: 44)
        .overlay { Capsule().strokeBorder(Board.onRaised.opacity(0.2), lineWidth: 1.5) }
        .sensoryFeedback(.selection, trigger: quantity)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let total = model.picksTotal {
                HStack(alignment: .firstTextBaseline) {
                    Text("Total").fontWeight(.semibold)
                    Spacer()
                    Text(model.price(total)).fontWeight(.semibold)
                    if let home = model.homePrice(total) {
                        Text("· \(home)").foregroundStyle(Board.onRaised2)
                    }
                }
                .font(.boardBody).monospacedDigit()
                .foregroundStyle(Board.onRaised)
            }
            ForEach(checks, id: \.self) { line in
                HStack(spacing: 10) {
                    Text(line.initial).font(.boardHeavy(13)).foregroundStyle(Board.onRaised)
                        .frame(width: 28, height: 28)
                        .overlay { Circle().strokeBorder(Board.onRaised.opacity(0.25), lineWidth: 1.5) }
                    Text(line.text).font(.boardSecondary).foregroundStyle(line.problem ? Board.noDeep : Board.onRaised2)
                }
            }
        }
        .padding(.bottom, 100)
    }

    private struct Check: Hashable { let initial: String; let text: String; let problem: Bool }

    /// One line per person: "Nothing on this list that Els can't have."
    private var checks: [Check] {
        let people = model.selectedProfile.map { [$0] } ?? model.profiles
        return people.map { person in
            let crossed = model.pickedDishes.filter { model.verdict(for: $0.dish, profile: person).kind == .no }
            if crossed.isEmpty {
                return Check(initial: person.initial, text: "Nothing on this list that \(person.name) can't have.",
                             problem: false)
            }
            let names = crossed.map(\.dish.name).joined(separator: ", ")
            return Check(initial: person.initial, text: "\(names): not for \(person.name).", problem: true)
        }
    }
}
