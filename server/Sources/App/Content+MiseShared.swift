import Vapor
import MiseShared

// The shared DTOs are plain `Codable` so they compile on both iOS and Linux.
// Vapor's `Content` adds request/response (de)coding on top — conform here in
// the server target. `Content`'s protocol extensions supply the implementations.
extension ParseMenuRequest: @retroactive Content {}
extension ParseMenuResponse: @retroactive Content {}
extension DishImagesRequest: @retroactive Content {}
extension DishImagesResponse: @retroactive Content {}
extension PhrasesRequest: @retroactive Content {}
extension PhraseSet: @retroactive Content {}
