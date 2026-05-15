//
//  GiteaAPI.swift
//  Gitea Helper
//
//  Created by Elias on 2026/5/15.
//

import Foundation

enum GiteaAPIError: LocalizedError {
    case invalidURL
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The Gitea URL is invalid."
        case let .requestFailed(status, message):
            if status == 401 {
                return "Authentication failed. Check that the token is correct, not expired, and has the required Gitea permissions."
            }
            return "Gitea returned \(status): \(message)"
        }
    }
}

struct GiteaAPI {
    let baseURL: String
    let token: String

    func currentUser() async throws -> GiteaUser {
        try await send("/api/v1/user")
    }

    func createUser(username: String, email: String, password: String) async throws {
        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": password,
            "must_change_password": false
        ]
        try await sendWithoutBody("/api/v1/admin/users", method: "POST", body: body, acceptedStatusCodes: [201, 422])
    }

    func createRepository(for username: String, name: String) async throws {
        let body: [String: Any] = [
            "name": name,
            "private": true,
            "auto_init": true
        ]
        let path = "/api/v1/admin/users/\(username.urlPathEncoded)/repos"
        try await sendWithoutBody(path, method: "POST", body: body, acceptedStatusCodes: [201, 409, 422])
    }

    func createTestRepository(name: String, description: String, readme: String) async throws -> String {
        let user = try await currentUser()
        let body: [String: Any] = [
            "name": name,
            "private": false,
            "auto_init": false,
            "description": description.isEmpty ? "Test project created via Gitea Helper" : description
        ]
        try await sendWithoutBody("/api/v1/user/repos", method: "POST", body: body, acceptedStatusCodes: [201, 409, 422])

        let readmeBody: [String: Any] = [
            "content": Data((readme.isEmpty ? "# \(name)" : readme).utf8).base64EncodedString(),
            "message": "Initial commit: Add README.md"
        ]
        let readmePath = "/api/v1/repos/\(user.username.urlPathEncoded)/\(name.urlPathEncoded)/contents/README.md"
        try await sendWithoutBody(readmePath, method: "POST", body: readmeBody, acceptedStatusCodes: [201, 409, 422])
        return "\(user.username)/\(name)"
    }

    func deleteRepository(owner: String, name: String) async throws {
        let path = "/api/v1/repos/\(owner.urlPathEncoded)/\(name.urlPathEncoded)"
        try await sendWithoutBody(path, method: "DELETE", acceptedStatusCodes: [204])
    }

    func repositories() async throws -> [GiteaRepository] {
        let response: RepoSearchResponse = try await send("/api/v1/repos/search?limit=1000")
        return response.data
    }

    func users() async throws -> [GiteaUser] {
        try await send("/api/v1/admin/users?limit=1000")
    }

    func deleteUser(username: String) async throws {
        let path = "/api/v1/admin/users/\(username.urlPathEncoded)?purge=true"
        try await sendWithoutBody(path, method: "DELETE", acceptedStatusCodes: [204])
    }

    private func send<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await perform(path: path, method: "GET", body: nil, acceptedStatusCodes: [200])
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sendWithoutBody(_ path: String, method: String, body: [String: Any]? = nil, acceptedStatusCodes: Set<Int>) async throws {
        _ = try await perform(path: path, method: method, body: body, acceptedStatusCodes: acceptedStatusCodes)
    }

    private func perform(path: String, method: String, body: [String: Any]?, acceptedStatusCodes: Set<Int>) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: normalizedBaseURL + path) else {
            throw GiteaAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("token \(normalizedToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GiteaAPIError.requestFailed(0, "No HTTP response.")
        }

        guard acceptedStatusCodes.contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw GiteaAPIError.requestFailed(httpResponse.statusCode, message)
        }

        return (data, httpResponse)
    }

    private var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingSuffix("/")
    }

    private var normalizedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RepoSearchResponse: Decodable {
    let data: [GiteaRepository]
}

private extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }

    func trimmingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else { return self }
        return String(dropLast(suffix.count))
    }
}

