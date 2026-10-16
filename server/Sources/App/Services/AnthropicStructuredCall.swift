import Vapor
import NIOCore

/// One Anthropic Messages API call that returns JSON matching a schema
/// (structured outputs). Shared by the menu parser and the phrase writer.
///
/// There is no official Anthropic Swift SDK, so this calls the REST API directly.
struct AnthropicStructuredCall {
    let apiKey: String
    let model: String

    static let endpoint = URI(string: "https://api.anthropic.com/v1/messages")
    static let apiVersion = "2023-06-01"

    /// Sends `system` + `user` and returns the raw JSON text of the first text block.
    func run(
        system: String,
        user: String,
        schema: JSONValue,
        maxTokens: Int,
        client: any Client,
        timeout: TimeAmount? = nil
    ) async throws -> Data {
        let requestBody = AnthropicRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: [.init(role: "user", content: user)],
            output_config: .init(format: .init(type: "json_schema", schema: schema))
        )

        var clientRequest = ClientRequest(method: .POST, url: Self.endpoint)
        clientRequest.headers.replaceOrAdd(name: "x-api-key", value: apiKey)
        clientRequest.headers.replaceOrAdd(name: "anthropic-version", value: Self.apiVersion)
        clientRequest.headers.contentType = .json
        try clientRequest.content.encode(requestBody)
        clientRequest.timeout = timeout

        let response = try await client.send(clientRequest)

        guard response.status == .ok else {
            let bodyText = response.body.map { String(buffer: $0) } ?? ""
            throw Abort(.badGateway, reason: "Anthropic returned \(response.status): \(bodyText)")
        }

        let decoded = try response.content.decode(AnthropicResponse.self)
        guard let json = decoded.content.first(where: { $0.type == "text" })?.text,
              let data = json.data(using: .utf8) else {
            throw Abort(.badGateway, reason: "Anthropic response contained no text block.")
        }
        return data
    }
}

// MARK: - Wire types

private struct AnthropicRequest: Content {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [Message]
    let output_config: OutputConfig

    struct Message: Content {
        let role: String
        let content: String
    }

    struct OutputConfig: Content {
        let format: Format
    }

    struct Format: Content {
        let type: String
        let schema: JSONValue
    }
}

private struct AnthropicResponse: Content {
    let content: [Block]

    struct Block: Content {
        let type: String
        let text: String?
    }
}

extension JSONValue {
    static let stringType: JSONValue = .object(["type": .string("string")])
    static let nullableString: JSONValue = .object(["type": .array([.string("string"), .string("null")])])

    static func stringEnum(_ values: [String]) -> JSONValue {
        .object(["type": .string("string"), "enum": .array(values.map(JSONValue.string))])
    }

    static func arrayOf(_ items: JSONValue) -> JSONValue {
        .object(["type": .string("array"), "items": items])
    }
}
