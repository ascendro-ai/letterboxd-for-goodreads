import Foundation

@Observable
final class ChallengeService {
    static let shared = ChallengeService()
    private let api = APIClient.shared

    private init() {}

    func createChallenge(_ request: CreateChallengeRequest) async throws -> ReadingChallenge {
        try await api.request(.post, path: "/me/challenges", body: request)
    }

    func getChallenges() async throws -> [ReadingChallenge] {
        try await api.request(.get, path: "/me/challenges")
    }

    func getChallenge(year: Int) async throws -> ReadingChallenge {
        try await api.request(.get, path: "/me/challenges/\(year)")
    }

    func updateChallenge(year: Int, request: UpdateChallengeRequest) async throws -> ReadingChallenge {
        try await api.request(.patch, path: "/me/challenges/\(year)", body: request)
    }
}
