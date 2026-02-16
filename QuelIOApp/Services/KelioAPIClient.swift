import Foundation

enum APIClientError: LocalizedError {
    case invalidURL
    case invalidCredentials
    case tokenInvalidated
    case tokenExpired
    case cancelled
    case badResponse(String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL API invalide"
        case .invalidCredentials:
            return "Identifiants invalides"
        case .tokenInvalidated:
            return "Votre session a été invalidée."
        case .tokenExpired:
            return "Session expirée."
        case .cancelled:
            return "Requête annulée"
        case let .badResponse(message):
            return message
        case let .transport(error):
            return "Erreur réseau: \(error.localizedDescription)"
        }
    }
}

struct KelioAPIClient {
    private static let retryDelaysNanoseconds: [UInt64] = [0, 350_000_000, 1_000_000_000]
    private static let retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .networkConnectionLost,
        .notConnectedToInternet,
        .cannotLoadFromNetwork,
        .resourceUnavailable
    ]

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
    }

    func login(
        baseURL: String,
        username: String,
        password: String?,
        token: String?
    ) async throws -> KelioAPIResponse {
        var fields: [String: String] = ["action": "login"]

        if let password, !password.isEmpty {
            fields["username"] = username
            fields["password"] = password
            return try await post(baseURL: baseURL, fields: fields, tokenLogin: false)
        }

        if let token, !token.isEmpty {
            fields["username"] = username
            fields["token"] = token
            return try await post(baseURL: baseURL, fields: fields, tokenLogin: true)
        }

        throw APIClientError.invalidCredentials
    }

    func updatePreferences(
        baseURL: String,
        token: String,
        theme: AppTheme,
        minutesObjective: Int
    ) async throws -> KelioAPIResponse {
        let fields: [String: String] = [
            "action": "update_preferences",
            "token": token,
            "theme": theme.rawValue,
            "minutes_objective": String(minutesObjective)
        ]

        return try await post(baseURL: baseURL, fields: fields, tokenLogin: false)
    }

    private func post(
        baseURL: String,
        fields: [String: String],
        tokenLogin: Bool
    ) async throws -> KelioAPIResponse {
        guard let url = normalizedURL(from: baseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded(fields).data(using: .utf8)

        let maxAttempts = Self.retryDelaysNanoseconds.count
        var lastError: APIClientError = .badResponse("Erreur de connexion")

        for attempt in 0..<maxAttempts {
            if Task.isCancelled {
                throw APIClientError.cancelled
            }
            if attempt > 0 {
                do {
                    try await Task.sleep(nanoseconds: Self.retryDelaysNanoseconds[attempt])
                } catch {
                    throw APIClientError.cancelled
                }
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIClientError.badResponse("Réponse serveur invalide")
                }

                if !(200...299).contains(http.statusCode) {
                    if shouldRetry(statusCode: http.statusCode, attempt: attempt, maxAttempts: maxAttempts) {
                        continue
                    }

                    if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                        if envelope.tokenInvalidated == true {
                            throw APIClientError.tokenInvalidated
                        }
                        if let message = envelope.error {
                            if tokenLogin, http.statusCode == 401 {
                                throw APIClientError.tokenExpired
                            }
                            throw APIClientError.badResponse(message)
                        }
                    }

                    if tokenLogin, http.statusCode == 401 {
                        throw APIClientError.tokenExpired
                    }

                    throw APIClientError.badResponse("Erreur serveur (\(http.statusCode))")
                }

                let payload: KelioAPIResponse
                do {
                    payload = try decoder.decode(KelioAPIResponse.self, from: data)
                } catch {
                    if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data),
                       let message = envelope.error {
                        throw APIClientError.badResponse(message)
                    }

                    let snippet = String(data: data.prefix(300), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Réponse non lisible"
                    throw APIClientError.badResponse("Réponse API inattendue: \(snippet)")
                }

                if let message = payload.error,
                   !message.localizedCaseInsensitiveContains("using cached data") {
                    throw APIClientError.badResponse(message)
                }

                return payload
            } catch {
                let normalized = normalizedError(error)
                lastError = normalized

                if shouldRetry(error: normalized, attempt: attempt, maxAttempts: maxAttempts) {
                    continue
                }

                throw normalized
            }
        }

        throw lastError
    }

    private func formURLEncoded(_ fields: [String: String]) -> String {
        fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
    }

    private func escape(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func normalizedURL(from value: String) -> URL? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if !text.contains("://") {
            text = "http://\(text)"
        }

        if !text.hasSuffix("/") {
            text += "/"
        }

        return URL(string: text)
    }

    private func normalizedError(_ error: Error) -> APIClientError {
        if let apiError = error as? APIClientError {
            return apiError
        }

        if error is CancellationError {
            return .cancelled
        }

        if let urlError = error as? URLError {
            if urlError.code == .cancelled {
                return .cancelled
            }
            return .transport(urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return .cancelled
        }

        return .transport(error)
    }

    private func shouldRetry(statusCode: Int, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt + 1 < maxAttempts else { return false }
        return Self.retryableStatusCodes.contains(statusCode)
    }

    private func shouldRetry(error: APIClientError, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt + 1 < maxAttempts else { return false }

        switch error {
        case let .transport(error):
            guard let urlError = error as? URLError else {
                return false
            }
            return Self.retryableURLErrorCodes.contains(urlError.code)
        default:
            return false
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("API Client Errors") {
    VStack(alignment: .leading, spacing: 6) {
        Text(APIClientError.invalidURL.errorDescription ?? "")
        Text(APIClientError.cancelled.errorDescription ?? "")
        Text(APIClientError.transport(URLError(.timedOut)).errorDescription ?? "")
    }
    .font(.caption)
    .padding()
}
#endif
