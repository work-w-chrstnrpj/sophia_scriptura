import PhotosUI
import SwiftUI

struct SettingsUserProfileView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userProfile: UserProfileSession

    @State private var name = ""
    @State private var birthday = Date()
    @State private var includesBirthday = false
    @State private var church = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var draftPhoto: UIImage?
    @State private var removePhoto = false
    @State private var notice: String?

    var body: some View {
        Form {
                Section {
                    VStack(spacing: 16) {
                        profileAvatar(size: 96)
                        HStack(spacing: 20) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Choose Photo")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(theme.palette.accent))
                            Button("Remove photo", role: .destructive) {
                                draftPhoto = nil
                                removePhoto = true
                                photoItem = nil
                            }
                            .buttonStyle(.plain)
                            .disabled(!hasProfilePhoto)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color(theme.palette.soft))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                Section("About you") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .accessibilityIdentifier("settings.profile.name")
                    Toggle("Include birthday", isOn: $includesBirthday)
                    if includesBirthday {
                        DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                            .accessibilityIdentifier("settings.profile.birthday")
                    }
                    TextField("Church you attend", text: $church, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("settings.profile.church")
                }
                .listRowBackground(Color(theme.palette.soft))

                if let notice {
                    Section {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                    .listRowBackground(Color(theme.palette.soft))
                }
            }
            .appSurface()
            .navigationTitle("Your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("settings.profile.save")
                }
            }
            .onAppear(perform: loadDraft)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: data) {
                            draftPhoto = image
                            removePhoto = false
                        } else {
                            notice = "That image could not be used."
                        }
                    }
                }
            }
        .accessibilityIdentifier("settings.profile.sheet")
    }

    private var hasProfilePhoto: Bool {
        draftPhoto != nil || userProfile.profilePhoto != nil
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        let image = draftPhoto ?? userProfile.profilePhoto
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(theme.palette.secondary))
                    .padding(size * 0.12)
                    .background(Color(theme.palette.soft))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(theme.palette.rule), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func loadDraft() {
        name = userProfile.profile.displayName
        church = userProfile.profile.churchName
        if let birthday = userProfile.profile.birthday {
            includesBirthday = true
            self.birthday = birthday
        } else {
            includesBirthday = false
        }
        draftPhoto = nil
        removePhoto = false
        notice = nil
    }

    private func save() {
        userProfile.update(
            displayName: name,
            birthday: includesBirthday ? birthday : nil,
            churchName: church
        )
        if removePhoto {
            userProfile.setProfilePhoto(nil)
        } else if let draftPhoto, let data = draftPhoto.jpegData(compressionQuality: 0.88) {
            userProfile.setProfilePhoto(data)
        }
        dismiss()
    }
}
