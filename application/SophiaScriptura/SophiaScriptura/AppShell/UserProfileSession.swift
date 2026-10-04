import SwiftUI

@MainActor
final class UserProfileSession: ObservableObject {
    @Published private(set) var profile = UserProfile.initial
    @Published private(set) var profilePhoto: UIImage?

    init() {
        profile = UserProfileStore.load()
        profilePhoto = UserProfileStore.loadPhoto()
    }

    func update(displayName: String, birthday: Date?, churchName: String) {
        var next = profile
        next.displayName = String(displayName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        next.birthday = birthday
        next.churchName = String(churchName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        profile = next
        UserProfileStore.save(next)
    }

    func setProfilePhoto(_ data: Data?) {
        if let data {
            do {
                try UserProfileStore.savePhoto(data)
                profilePhoto = UIImage(data: data)
            } catch {
                profilePhoto = UserProfileStore.loadPhoto()
            }
        } else {
            UserProfileStore.removePhoto()
            profilePhoto = nil
        }
    }

    var scriptureGreeting: String {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Hello. How can I help you with your question?"
        }
        return "Hello, \(name). How can I help you with your question?"
    }
}
