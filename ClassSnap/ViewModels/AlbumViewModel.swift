import Foundation
import Photos
import Observation

@MainActor
@Observable
final class AlbumViewModel {
    private let photoService = PhotoLibraryService()
    private let matcher = PhotoMatcher()

    var albums: [ClassAlbum] = []
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var isLoading: Bool = false
    var errorMessage: String?

    func loadAlbums(schedules: [ClassSchedule]) async {
        guard !schedules.isEmpty else {
            albums = []
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let status = await photoService.requestAuthorization()
        authorizationStatus = status

        guard status == .authorized || status == .limited else {
            errorMessage = "写真ライブラリへのアクセス権が必要です。\n設定アプリから許可してください。"
            return
        }

        // fetchAllAssets は同期 API のためバックグラウンドスレッドで実行
        let assets = await Task.detached(priority: .userInitiated) { [photoService] in
            photoService.fetchAllAssets()
        }.value

        matcher.bufferSeconds = AppSettings.shared.bufferMinutes * 60
        var matched = matcher.match(assets: assets, schedules: schedules)

        // 手動追加写真の PHKit フェッチは同期 API のためバックグラウンドで解決し、
        // 各アルバムに事前格納する（ViewパスでのPHKitアクセスを避ける）。
        let scheduleIDs = matched.map { $0.schedule.id }
        let manualByID = await Task.detached(priority: .userInitiated) {
            var dict: [UUID: [PHAsset]] = [:]
            for id in scheduleIDs {
                dict[id] = PhotoInclusionStore.shared.fetchAssets(for: id)
            }
            return dict
        }.value
        for i in matched.indices {
            matched[i].manualAssets = manualByID[matched[i].schedule.id] ?? []
        }
        albums = matched
    }
}
