//
//  AppInfo.swift
//  Hade
//
//  Uygulama meta bilgileri ve depo bağlantıları.
//

import Foundation

enum AppInfo {
    static let appName = "Hade"

    // MARK: - GitHub deposu
    // NOT: Kendi deponuza göre güncelleyin.
    static let repoOwner = "MrJusovic"
    static let repoName = "Hade"

    static var repoURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)")!
    }
    static var releasesURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
    }
    static var licenseURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/blob/main/LICENSE")!
    }
    static var latestReleaseAPI: URL {
        URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    }

    // MARK: - Sürüm
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
