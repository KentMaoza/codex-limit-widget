import Foundation

struct CodexAuth: Decodable, Sendable {
    let tokens: Tokens

    struct Tokens: Decodable, Sendable {
        let accessToken: String
        let accountId: String?
    }
}
