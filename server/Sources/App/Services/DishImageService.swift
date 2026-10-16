import Vapor
import MiseShared

/// One tier of the free dish-photo chain (Wikimedia Commons, Pexels, Pixabay).
///
/// A provider says which search terms to try for a dish, in order, and runs one
/// search per term. Tests inject fakes; nothing here may call a paid or
/// generative image API — dish photos must cost $0/month.
protocol ImageProvider: Sendable {
    /// Short name for logs ("commons").
    var name: String { get }
    /// Search terms to try for `dish`, in order. Empty skips the tier.
    func terms(for dish: DishImageQuery) -> [String]
    /// One search; `nil` is a miss.
    func search(term: String, client: any Client, logger: Logger) async throws -> DishImage?
}

/// Finds a typical photo for each dish: Commons, then Pexels, then Pixabay,
/// else `nil` (the app draws the plate archetype). Results, misses included,
/// are cached by "name|cuisine" so each dish is looked up once across menus.
struct DishImageService: Sendable {
    let providers: [any ImageProvider]
    let cache: DishImageCache
    /// How many dishes are looked up at once.
    let concurrency: Int
    /// Upper bound on one provider call, so a slow tier never blocks the batch.
    let callTimeout: Duration

    static let maxBatch = 60

    init(
        providers: [any ImageProvider],
        cache: DishImageCache = DishImageCache(),
        concurrency: Int = 4,
        callTimeout: Duration = .seconds(8)
    ) {
        self.providers = providers
        self.cache = cache
        self.concurrency = max(1, concurrency)
        self.callTimeout = callTimeout
    }

    /// The default free chain. Pexels and Pixabay join only when their keys are set.
    static func live(pexelsKey: String?, pixabayKey: String?) -> DishImageService {
        var providers: [any ImageProvider] = [CommonsImageProvider()]
        if let pexelsKey, !pexelsKey.isEmpty { providers.append(PexelsImageProvider(apiKey: pexelsKey)) }
        if let pixabayKey, !pixabayKey.isEmpty { providers.append(PixabayImageProvider(apiKey: pixabayKey)) }
        return DishImageService(providers: providers)
    }

    static func cacheKey(for dish: DishImageQuery) -> String {
        "\(dish.name)|\(dish.cuisine ?? "")".lowercased()
    }

    func images(for dishes: [DishImageQuery], client: any Client, logger: Logger) async -> [DishImageResult] {
        var results = [DishImage?](repeating: nil, count: dishes.count)
        await withTaskGroup(of: (Int, DishImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < dishes.count else { return }
                let index = next
                let dish = dishes[index]
                next += 1
                group.addTask { (index, await self.image(for: dish, client: client, logger: logger)) }
            }
            for _ in 0..<min(concurrency, dishes.count) { addNext() }
            while let (index, image) = await group.next() {
                results[index] = image
                addNext()
            }
        }
        return zip(dishes, results).map { DishImageResult(id: $0.id, image: $1) }
    }

    func image(for dish: DishImageQuery, client: any Client, logger: Logger) async -> DishImage? {
        await cache.value(for: Self.cacheKey(for: dish)) {
            await self.lookup(dish, client: client, logger: logger)
        }
    }

    /// Walks the chain, stopping at the first hit. Errors and timeouts count as misses.
    private func lookup(_ dish: DishImageQuery, client: any Client, logger: Logger) async -> DishImage? {
        for provider in providers {
            for term in provider.terms(for: dish) {
                do {
                    let found = try await withTimeout(callTimeout) {
                        try await provider.search(term: term, client: client, logger: logger)
                    }
                    if let found { return found }
                } catch {
                    logger.warning("Image provider \(provider.name) failed for \"\(term)\": \(error)")
                }
            }
        }
        return nil
    }
}

struct ImageLookupTimeout: Error {}

/// Runs `operation`, throwing `ImageLookupTimeout` if it takes longer than `limit`.
func withTimeout<T: Sendable>(
    _ limit: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw ImageLookupTimeout()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

// MARK: - Cache

/// In-memory cache of dish photos by key. Hits live for the process; misses
/// expire after `missTTL` so a dish gets another chance later. Concurrent
/// requests for the same key share one lookup.
actor DishImageCache {
    private struct Entry {
        let image: DishImage?
        let storedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<DishImage?, Never>] = [:]
    let missTTL: TimeInterval
    private let now: @Sendable () -> Date

    init(missTTL: TimeInterval = 7 * 24 * 60 * 60, now: @escaping @Sendable () -> Date = Date.init) {
        self.missTTL = missTTL
        self.now = now
    }

    func value(for key: String, compute: @escaping @Sendable () async -> DishImage?) async -> DishImage? {
        if let entry = entries[key] {
            if entry.image != nil || now().timeIntervalSince(entry.storedAt) < missTTL {
                return entry.image
            }
            entries[key] = nil
        }
        if let task = inFlight[key] { return await task.value }
        let task = Task { await compute() }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        entries[key] = Entry(image: image, storedAt: now())
        return image
    }

    var count: Int { entries.count }
}

// MARK: - Application storage

extension Application {
    private struct DishImageServiceKey: StorageKey {
        typealias Value = DishImageService
    }

    var dishImages: DishImageService {
        get {
            guard let service = storage[DishImageServiceKey.self] else {
                fatalError("DishImageService not configured. Call configure(_:) first.")
            }
            return service
        }
        set { storage[DishImageServiceKey.self] = newValue }
    }
}
