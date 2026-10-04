import Foundation
import UIKit

struct UserProfile: Equatable, Sendable {
    var displayName: String = ""
    var birthday: Date?
    var churchName: String = ""

    static let initial = UserProfile()
}

enum UserProfileStore {
    private static let defaults = UserDefaults.standard
    private static let nameKey = "userProfile.displayName"
    private static let birthdayKey = "userProfile.birthday"
    private static let churchKey = "userProfile.churchName"

    static func load() -> UserProfile {
        UserProfile(
            displayName: defaults.string(forKey: nameKey) ?? "",
            birthday: defaults.object(forKey: birthdayKey) as? Date,
            churchName: defaults.string(forKey: churchKey) ?? ""
        )
    }

    static func save(_ profile: UserProfile) {
        defaults.set(profile.displayName, forKey: nameKey)
        if let birthday = profile.birthday {
            defaults.set(birthday, forKey: birthdayKey)
        } else {
            defaults.removeObject(forKey: birthdayKey)
        }
        defaults.set(profile.churchName, forKey: churchKey)
    }

    static var photoURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("UserProfile", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("profile-photo.jpg")
    }

    static func loadPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else { return nil }
        return UIImage(data: data)
    }

    static func savePhoto(_ data: Data) throws {
        guard data.count <= 4 * 1024 * 1024 else { throw UserProfileError.photoTooLarge }
        try data.write(to: photoURL, options: .atomic)
    }

    static func removePhoto() {
        try? FileManager.default.removeItem(at: photoURL)
    }
}

enum UserProfileError: LocalizedError {
    case photoTooLarge

    var errorDescription: String? {
        switch self {
        case .photoTooLarge: "Choose a photo smaller than 4 MB."
        }
    }
}
