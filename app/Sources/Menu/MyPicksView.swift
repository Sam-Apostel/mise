import SwiftUI
import MiseShared

/// Frame 06 — My picks. The table's shortlist, with a total and a share/show-waiter action.
struct MyPicksView: View {
    @Environment(ScanSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if session.picks.isEmpty {
                ContentUnavailableView("No picks yet", systemImage: "bookmark",
                                       description: Text("Add dishes from the menu to build a list for the table."))
            } else {
                content
            }
        }
        .background(Theme.page)
        .navigationTitle("My picks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Text("\(session.picks.count) \(session.picks.count == 1 ? "dish" : "dishes") · for the table")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 12)

                    ForEach(session.picks) { dish in
                        pickRow(dish)
                        Divider().overlay(Theme.hairline).padding(.leading, 84)
                    }

                    totalRow
                }
            }
            shareBar
        }
    }

    private func pickRow(_ dish: Dish) -> some View {
        HStack(alignment: .center, spacing: 12) {
            DishThumbnail(dish: dish, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(dish.name)
                    .font(.serifTitle(16))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    if let price = dish.price {
                        Text(formattedPrice(price, currency: dish.currency))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                    if dish.course != .other {
                        Text("· \(dish.course.displayName.dropLast().lowercased())")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            Spacer()
            Button {
                session.togglePick(dish)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var totalRow: some View {
        if let total = session.picksTotal {
            HStack {
                Text("Total").font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                Text(formattedPrice(total, currency: session.picksCurrency))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .padding()
        }
    }

    private var shareBar: some View {
        ShareLink(item: session.picksShareText) {
            Label("Show waiter / share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.corner).stroke(Theme.ink, lineWidth: 1.5))
                .padding()
        }
        .background(.ultraThinMaterial)
    }
}

#Preview {
    let session = ScanSession.previewLoaded
    session.pickedIDs = Set(session.menu!.dishes.prefix(3).map(\.id))
    return NavigationStack { MyPicksView() }
        .environment(session)
}
