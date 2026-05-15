//
//  GiteaModels.swift
//  Gitea Helper
//
//  Created by Elias on 2026/5/15.
//

import Foundation
import SwiftData

@Model
final class GiteaHost {
    var name: String
    var baseURL: String
    var adminToken: String
    var emailDomain: String = "skills.edu"
    var isSelected: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \GeneratedAccount.host)
    var accounts: [GeneratedAccount]

    init(name: String, baseURL: String, adminToken: String, isSelected: Bool = false) {
        self.name = name
        self.baseURL = baseURL
        self.adminToken = adminToken
        self.emailDomain = "skills.edu"
        self.isSelected = isSelected
        self.createdAt = Date()
        self.accounts = []
    }
}

@Model
final class GeneratedAccount {
    var username: String
    var email: String
    var password: String
    var createdAt: Date
    var host: GiteaHost?

    init(username: String, email: String, password: String, host: GiteaHost?) {
        self.username = username
        self.email = email
        self.password = password
        self.createdAt = Date()
        self.host = host
    }
}

struct GiteaRepository: Identifiable, Decodable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlURL: String?
    let isPrivate: Bool
    let owner: GiteaUser?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case htmlURL = "html_url"
        case isPrivate = "private"
        case owner
    }
}

struct GiteaUser: Identifiable, Decodable {
    let id: Int
    let username: String
    let email: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case isAdmin = "is_admin"
    }
}

