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

        let (startDate, endDate) = photoService.defaultDateRange()

        // fetchAssets は同期 API のためバックグラウンドスレッドで実行
        let assets = await Task.detached(priority: .userInitiated) { [photoService] in
            photoService.fetchAssets(from: startDate, to: endDate)
        }.value

        albums = matcher.match(assets: assets, schedules: schedules)
    }
}
