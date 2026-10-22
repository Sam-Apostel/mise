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
    /// How many searches may be in flight at once, across all requests.
    var maxConcurrent: Int { get }
    /// Search terms to try for `dish`, in order. Empty skips the tier.
    func terms(for dish: DishImageQuery) -> [String]
    /// One search; `nil` is a miss. Throws `ImageProviderRateLimited` on a 429.
    func search(term: String, dish: DishImageQuery, client: any Client, logger: Logger) async throws -> DishImage?
}

/// Finds a typical photo for each dish: Commons, then Pexels, then Pixabay,
/// else `nil` (the app draws the plate archetype).
///
/// Only a real answer is cached: a hit, or every tier saying "nothing". A tier
/// that failed, timed out or was rate-limited leaves the dish uncached and
/// marked `retry`, so one bad minute does not hide photos for a week.
struct DishImageService: Sendable {
    let providers: [any ImageProvider]
    let cache: DishImageCache
    /// How many dishes are looked up at once.
    let concurrency: Int
    /// Upper bound on one provider call, so a slow tier never blocks the batch.
    let callTimeout: Duration
    /// Time one request may spend; dishes not reached by then come back `retry`.
    let budget: Duration
    /// One gate per provider name: its concurrency limit and rate-limit cool-down.
    private let gates: [String: ProviderGate]

    static let maxBatch = 60

    init(
        providers: [any ImageProvider],
        cache: DishImageCache = DishImageCache(),
        concurrency: Int = 4,
        callTimeout: Duration = .seconds(8),
        budget: Duration = .seconds(25)
    ) {
        self.providers = providers
        self.cache = cache
        self.concurrency = max(1, concurrency)
        self.callTimeout = callTimeout
        self.budget = budget
        gates = Dictionary(providers.map { ($0.name, ProviderGate(limit: $0.maxConcurrent)) }) { first, _ in first }
    }

    /// The default free chain. Pexels and Pixabay join only when their keys are set.
    static func live(pexelsKey: String?, pixabayKey: String?) -> DishImageService {
        var providers: [any ImageProvider] = [CommonsImageProvider()]
        if let pexelsKey, !pexelsKey.isEmpty { providers.append(PexelsImageProvider(apiKey: pexelsKey)) }
        if let pixabayKey, !pixabayKey.isEmpty { providers.append(PixabayImageProvider(apiKey: pixabayKey)) }
        return DishImageService(providers: providers)
    }

    static func cacheKey(for dish: DishImageQuery) -> String {
        "\(dish.name)|\(dish.cuisine ?? "")|\(dish.searchKind ?? "")".lowercased()
    }

    func images(for dishes: [DishImageQuery], client: any Client, logger: Logger) async -> [DishImageResult] {
        let deadline = ContinuousClock.now + budget
        var results = [Lookup](repeating: .unavailable, count: dishes.count)
        await withTaskGroup(of: (Int, Lookup).self) { group in
            var next = 0
            func addNext() {
                guard next < dishes.count else { return }
                let index = next
                let dish = dishes[index]
                next += 1
                group.addTask { (index, await self.lookup(dish, deadline: deadline, client: client, logger: logger)) }
            }
            for _ in 0..<min(concurrency, dishes.count) { addNext() }
            while let (index, lookup) = await group.next() {
                results[index] = lookup
                addNext()
            }
        }
        return zip(dishes, results).map { DishImageResult(id: $0.id, image: $1.image, retry: $1 == .unavailable) }
    }

    func image(for dish: DishImageQuery, client: any Client, logger: Logger) async -> DishImage? {
        await lookup(dish, deadline: .now + budget, client: client, logger: logger).image
    }

    private func lookup(_ dish: DishImageQuery, deadline: ContinuousClock.Instant,
                        client: any Client, logger: Logger) async -> Lookup {
        await cache.value(for: Self.cacheKey(for: dish)) {
            await self.walk(dish, deadline: deadline, client: client, logger: logger)
        }
    }

    /// Walks the chain, stopping at the first hit.
    private func walk(_ dish: DishImageQuery, deadline: ContinuousClock.Instant,
                      client: any Client, logger: Logger) async -> Lookup {
        var answered = true
        for provider in providers {
            guard let gate = gates[provider.name] else { continue }
            terms: for term in provider.terms(for: dish) {
                switch await search(provider, gate: gate, term: term, dish: dish, deadline: deadline,
                                    client: client, logger: logger) {
                case .hit(let image): return .hit(image)
                case .miss: continue
                case .unavailable:
                    // This tier is out for now; the next one may still answer.
                    answered = false
                    break terms
                }
            }
        }
        return answered ? .miss : .unavailable
    }

    /// One search through the provider's gate. A 429 cools the provider down for
    /// everyone; a short `Retry-After` is waited out once.
    private func search(_ provider: any ImageProvider, gate: ProviderGate, term: String, dish: DishImageQuery,
                        deadline: ContinuousClock.Instant, client: any Client, logger: Logger) async -> Lookup {
        for attempt in 0..<2 {
            guard ContinuousClock.now < deadline, await gate.acquire(before: deadline) else { return .unavailable }
            do {
                let found = try await withTimeout(callTimeout) {
                    try await provider.search(term: term, dish: dish, client: client, logger: logger)
                }
                await gate.release()
                return found.map(Lookup.hit) ?? .miss
            } catch let limited as ImageProviderRateLimited {
                let wait = limited.retryAfter ?? .seconds(30)
                await gate.release(coolingFor: min(max(wait, .seconds(1)), .seconds(300)))
                logger.warning("\(limited); skipping \(provider.name) until it recovers")
                guard attempt == 0, wait <= .seconds(2), ContinuousClock.now + wait < deadline else { return .unavailable }
                try? await Task.sleep(for: wait)
            } catch {
                await gate.release()
                logger.warning("Image provider \(provider.name) failed for \"\(term)\": \(error)")
                return .unavailable
            }
        }
        return .unavailable
    }
}

/// What one lookup found. Only `.hit` and `.miss` are answers worth caching.
enum Lookup: Equatable, Sendable {
    case hit(DishImage)
    case miss
    /// A tier failed, timed out or was rate-limited: try again later.
    case unavailable

    var image: DishImage? {
        if case .hit(let image) = self { image } else { nil }
    }
}

/// Limits how many searches one provider runs at once, and holds it off after a 429.
actor ProviderGate {
    let limit: Int
    private var running = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var coolingUntil: ContinuousClock.Instant?

    init(limit: Int) { self.limit = max(1, limit) }

    /// Waits for a slot. `false` when the provider is cooling down past `deadline`.
    func acquire(before deadline: ContinuousClock.Instant) async -> Bool {
        if let coolingUntil, coolingUntil > .now { return false }
        if running < limit {
            running += 1
            return true
        }
        await withCheckedContinuation { waiters.append($0) }
        // `release` handed this waiter its slot; the provider may have started cooling meanwhile.
        if let coolingUntil, coolingUntil > .now || ContinuousClock.now >= deadline {
            release()
            return false
        }
        return true
    }

    func release(coolingFor cooldown: Duration? = nil) {
        if let cooldown { coolingUntil = .now + cooldown }
        if waiters.isEmpty {
            running -= 1
        } else {
            waiters.removeFirst().resume()
        }
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

/// In-memory cache of lookups by key. Hits live for the process; misses expire
/// after `missTTL` so a dish gets another chance later; `.unavailable` is never
/// stored. Concurrent requests for the same key share one lookup.
actor DishImageCache {
    private struct Entry {
        let image: DishImage?
        let storedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<Lookup, Never>] = [:]
    let missTTL: TimeInterval
    private let now: @Sendable () -> Date

    init(missTTL: TimeInterval = 7 * 24 * 60 * 60, now: @escaping @Sendable () -> Date = Date.init) {
        self.missTTL = missTTL
        self.now = now
    }

    func value(for key: String, compute: @escaping @Sendable () async -> Lookup) async -> Lookup {
        if let entry = entries[key] {
            if let image = entry.image { return .hit(image) }
            if now().timeIntervalSince(entry.storedAt) < missTTL { return .miss }
            entries[key] = nil
        }
        if let task = inFlight[key] { return await task.value }
        let task = Task { await compute() }
        inFlight[key] = task
        let lookup = await task.value
        inFlight[key] = nil
        switch lookup {
        case .hit(let image): entries[key] = Entry(image: image, storedAt: now())
        case .miss: entries[key] = Entry(image: nil, storedAt: now())
        case .unavailable: break
        }
        return lookup
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
