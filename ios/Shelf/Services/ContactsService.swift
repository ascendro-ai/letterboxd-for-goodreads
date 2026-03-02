/// Contacts sync for friend discovery.
/// Fetches device contacts, hashes emails/phone numbers with SHA-256,
/// and sends to the backend for matching against existing users.

import Contacts
import CryptoKit
import Foundation

@Observable
final class ContactsService {
    static let shared = ContactsService()

    private let api = APIClient.shared
    private let store = CNContactStore()

    private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined
    private(set) var matchedUsers: [User] = []
    private(set) var isSyncing = false

    private init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Request contacts permission. Returns true if granted.
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            return granted
        } catch {
            authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
            return false
        }
    }

    /// Fetch contacts, hash identifiers, sync with backend, return matched users.
    @MainActor
    func syncContacts() async throws -> [User] {
        guard !isSyncing else { return matchedUsers }
        isSyncing = true
        defer { isSyncing = false }

        let hashes = try fetchHashedContactIdentifiers()
        guard !hashes.isEmpty else {
            matchedUsers = []
            return []
        }

        let request = ContactsSyncRequest(hashedEmails: hashes.emails, hashedPhones: hashes.phones)
        let response: ContactsSyncResponse = try await api.request(.post, path: "/me/contacts-sync", body: request)
        matchedUsers = response.matchedUsers
        return matchedUsers
    }

    // MARK: - Private

    private struct HashedIdentifiers {
        let emails: [String]
        let phones: [String]

        var isEmpty: Bool { emails.isEmpty && phones.isEmpty }
    }

    private func fetchHashedContactIdentifiers() throws -> HashedIdentifiers {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        var emails: [String] = []
        var phones: [String] = []

        try store.enumerateContacts(with: fetchRequest) { contact, _ in
            for email in contact.emailAddresses {
                let normalized = (email.value as String).lowercased().trimmingCharacters(in: .whitespaces)
                emails.append(Self.sha256Hash(normalized))
            }
            for phone in contact.phoneNumbers {
                let normalized = Self.normalizePhone(phone.value.stringValue)
                phones.append(Self.sha256Hash(normalized))
            }
        }

        return HashedIdentifiers(emails: emails, phones: phones)
    }

    private static func sha256Hash(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Strip non-digit characters for consistent phone normalization.
    private static func normalizePhone(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }
}

// MARK: - Request / Response Models

struct ContactsSyncRequest: Codable {
    let hashedEmails: [String]
    let hashedPhones: [String]

    enum CodingKeys: String, CodingKey {
        case hashedEmails = "hashed_emails"
        case hashedPhones = "hashed_phones"
    }
}

struct ContactsSyncResponse: Codable {
    let matchedUsers: [User]

    enum CodingKeys: String, CodingKey {
        case matchedUsers = "matched_users"
    }
}
