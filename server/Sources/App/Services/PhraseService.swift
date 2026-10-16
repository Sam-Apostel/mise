import Vapor
import MiseShared

/// Writes the waiter-card phrases for one person.
///
/// Built-in languages (`PhraseBook.languages`) are answered offline. Others go
/// to the model when an Anthropic key is configured; without a key, or when
/// the call fails, the English set is returned so the card always renders.
struct PhraseService: Sendable {
    let apiKey: String?
    let model: String

    func phrases(for request: PhrasesRequest, client: any Client, logger: Logger) async -> PhraseSet {
        let allergens = Set(request.allergens)
        if let builtIn = PhraseBook.phrases(language: request.language, allergens: allergens, speech: request.speech) {
            return builtIn
        }
        let english = PhraseBook.phrases(language: "en", allergens: allergens, speech: request.speech)!
        guard let apiKey else { return english }
        do {
            let data = try await AnthropicStructuredCall(apiKey: apiKey, model: model).run(
                system: Self.systemPrompt,
                user: Self.userPrompt(for: request, english: english),
                schema: Self.schema,
                maxTokens: 1000,
                client: client,
                timeout: .seconds(30)
            )
            return try Self.decode(data, language: request.language, englishAllergy: english.allergy.first)
        } catch {
            logger.error("Anthropic phrases failed for \(request.language), returning English: \(error)")
            return english
        }
    }

    static func decode(_ data: Data, language: String, englishAllergy: String?) throws -> PhraseSet {
        let llm = try JSONDecoder().decode(LLMPhrases.self, from: data)
        let lines = llm.allergy.compactMap { Optional($0).nonEmpty }
        return PhraseSet(
            language: language,
            order: llm.order,
            thanks: llm.thanks,
            allergy: lines,
            allergyTranslation: lines.isEmpty ? nil : (llm.allergyTranslation.nonEmpty ?? englishAllergy)
        )
    }

    static let systemPrompt = """
    You write the short phrases a traveller shows a waiter on a card, in the waiter's language. \
    Use the natural, polite form a native speaker would use in a restaurant. Return:
    - `order`: the word or phrase that leads an order ("I'd like").
    - `thanks`: "thank you".
    - `allergy`: one or two short lines saying the person is allergic to the listed foods and \
    that the dish must contain none of them. Empty when there are no allergens.
    - `allergyTranslation`: the allergy lines in English, or null when there are none.
    """

    static func userPrompt(for request: PhrasesRequest, english: PhraseSet) -> String {
        """
        Language (BCP-47): \(request.language)
        Grammatical gender of the speaker: \(request.speech.rawValue)
        Allergic to: \(request.allergens.isEmpty ? "nothing" : request.allergens.map(\.rawValue).joined(separator: ", "))
        English allergy sentence: \(english.allergy.first ?? "none")
        """
    }

    static let schema: JSONValue = .schemaObject(
        properties: [
            "order": .stringType,
            "thanks": .stringType,
            "allergy": .arrayOf(.stringType),
            "allergyTranslation": .nullableString,
        ],
        required: ["order", "thanks", "allergy", "allergyTranslation"]
    )
}

private struct LLMPhrases: Codable {
    var order: String
    var thanks: String
    var allergy: [String]
    var allergyTranslation: String?
}

extension Application {
    private struct PhraseServiceKey: StorageKey {
        typealias Value = PhraseService
    }

    var phraseService: PhraseService {
        get { storage[PhraseServiceKey.self] ?? PhraseService(apiKey: nil, model: "") }
        set { storage[PhraseServiceKey.self] = newValue }
    }
}
