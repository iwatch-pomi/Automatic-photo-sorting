import SwiftUI
import Photos

struct ExcludedPhotosView: View {
    let schedules: [ClassSchedule]

    private let store = PhotoExclusionStore.shared

    // scheduleID がある授業だけ絞り込み、除外写真と一緒にまとめる
    private struct ScheduleGroup: Identifiable {
        let schedule: ClassSchedule
        var assets: [AlbumPhoto]
        var id: UUID { schedule.id }
    }

    @State private var groups: [ScheduleGroup] = []

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView(
                    "除外した写真はありません",
                    systemImage: "photo.badge.checkmark",
                    description: Text("写真グリッドで除外した写真がここに表示されます")
                )
            } else {
                List {
                    ForEach($groups) { $group in
                        Section {
                            ForEach(group.assets, id: \.id) { photo in
                                ExcludedPhotoRow(
                                    photo: photo,
                                    onRestore: {
                                        store.include(assetID: photo.id,
                                                      scheduleID: group.schedule.id)
                                        group.assets.removeAll { $0.id == photo.id }
                                        groups.removeAll { $0.assets.isEmpty }
                                    }
                                )
                                .listRowBackground(Color.appCard)
                            }
                        } header: {
                            Text(group.schedule.subjectName)
                                .foregroundStyle(Color.appGreen)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("除外した写真")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadGroups() }
    }

    private func loadGroups() {
        groups = schedules.compactMap { schedule in
            let assets = store.fetchAssets(for: schedule.id).map { AlbumPhoto(asset: $0) }
            return assets.isEmpty ? nil : ScheduleGroup(schedule: schedule, assets: assets)
        }
    }
}

private struct ExcludedPhotoRow: View {
    let photo: AlbumPhoto
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(photo: photo, size: CGSize(width: 120, height: 90))
                .frame(width: 72, height: 54)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(photo.creationDateDisplay)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("除外中")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button {
                onRestore()
            } label: {
                Text("除外を解除")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color.appGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
