import SwiftUI
import MiseShared

/// Frame 03 — filter-first browse. Pinned quick-filter bar + course tabs + dish list.
struct BrowseView: View {
    @Environment(ScanSession.self) private var session
    @State private var filterModel = MenuFilterModel()
    @State private var selectedCourse: Course?
    @State private var showingFilters = false
    @State private var showingPicks = false

    var body: some View {
        Group {
            if let menu = session.menu {
                content(for: menu)
            } else {
                ContentUnavailableView("No menu", systemImage: "menucard")
            }
        }
        .background(Theme.page)
        .navigationTitle(session.menu?.restaurantName ?? "Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showingFilters) {
            NavigationStack { FiltersView(model: filterModel, dishes: session.menu?.dishes ?? []) }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingPicks) {
            NavigationStack { MyPicksView() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Scan", systemImage: "camera") { session.reset() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingPicks = true } label: {
                Label("My picks", systemImage: "bookmark")
                    .badge(session.pickedIDs.count)
            }
            .disabled(session.pickedIDs.isEmpty)
        }
    }

    // MARK: - Content

    private func dishesForCourse(_ menu: ParsedMenu) -> [Dish] {
        let visible = filterModel.visible(in: menu)
        guard let selectedCourse else { return visible }
        return visible.filter { $0.course == selectedCourse }
    }

    @ViewBuilder
    private func content(for menu: ParsedMenu) -> some View {
        VStack(spacing: 0) {
            quickFilterBar
            courseTabs(for: menu)
            Divider().overlay(Theme.hairline)

            let dishes = dishesForCourse(menu)
            if dishes.isEmpty && filterModel.filter.isActive {
                EmptyMatchesView(model: filterModel, dishes: menu.dishes)
            } else {
                dishList(dishes, total: menu.dishes.count)
            }
        }
    }

    private var quickFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { showingFilters = true } label: {
                    Pill(text: "Filters", systemImage: "line.3.horizontal.decrease",
                         fg: .white, bg: Theme.accent)
                }

                // Active constraints shown inline; tap to remove.
                ForEach(Array(filterModel.filter.requiredTags), id: \.self) { tag in
                    removableChip(tag.displayName) { filterModel.toggleRequired(tag) }
                }
                ForEach(Array(filterModel.filter.excludedTags), id: \.self) { tag in
                    removableChip("no \(tag.displayName.lowercased())") { filterModel.toggleExcluded(tag) }
                }
                ForEach(Array(filterModel.filter.avoidAllergens), id: \.self) { allergen in
                    removableChip("no \(allergen.displayName.lowercased())") { filterModel.toggleAllergen(allergen) }
                }
                if let spice = filterModel.filter.maxSpice {
                    removableChip("≤ \(spice.displayName.lowercased())") { filterModel.setMaxSpice(nil) }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Theme.paper)
    }

    private func removableChip(_ text: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 4) {
                Text(text)
                Image(systemName: "xmark")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.hairline.opacity(0.5), in: .capsule)
        }
    }

    private func courseTabs(for menu: ParsedMenu) -> some View {
        let courses = Course.allCases.filter { course in menu.dishes.contains { $0.course == course } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                courseTab(title: "Menu", isSelected: selectedCourse == nil) { selectedCourse = nil }
                ForEach(courses, id: \.self) { course in
                    courseTab(title: course.displayName, isSelected: selectedCourse == course) {
                        selectedCourse = course
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Theme.paper)
    }

    private func courseTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                Rectangle()
                    .fill(isSelected ? Theme.accent : .clear)
                    .frame(height: 2)
            }
            .padding(.top, 10)
        }
    }

    private func dishList(_ dishes: [Dish], total: Int) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(countLine(showing: dishes.count, total: total))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                ForEach(dishes) { dish in
                    NavigationLink {
                        DishDetailView(dish: dish)
                    } label: {
                        DishRow(dish: dish)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.hairline).padding(.leading, 84)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func countLine(showing: Int, total: Int) -> String {
        if !filterModel.filter.isActive && selectedCourse == nil {
            return "All \(total) dishes · tap Filters to narrow"
        }
        return "\(showing) matching \(showing == 1 ? "dish" : "dishes")"
    }
}

/// A single dish row in the browse list.
private struct DishRow: View {
    let dish: Dish

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DishThumbnail(dish: dish)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(dish.name)
                        .font(.serifTitle(17))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if let price = dish.price {
                        Text(formattedPrice(price, currency: dish.currency))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                if let description = dish.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                DishTagStrip(dish: dish)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack { BrowseView() }
        .environment(ScanSession.previewLoaded)
}
