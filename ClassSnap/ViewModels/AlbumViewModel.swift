import Foundation
import Photos
import Observation
import UIKit

@MainActor
@Observable
final class AlbumViewModel {
    private let photoService = PhotoLibraryService()
    private let matcher = PhotoMatcher()
    private let savedStore = SavedPhotoStore.shared

    var albums: [ClassAlbum] = []
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var isLoading: Bool = false
    var errorMessage: String?

    /// 保存時に長辺をこのピクセル数までにキャップ（容量対策）
    private let maxSavedDimension: CGFloat = 3024
    private let savedJPEGQuality: CGFloat = 0.9

    func loadAlbums(schedules: [ClassSchedule],
                    terms: [AcademicTerm] = [],
                    makeupsBySchedule: [UUID: [MakeupClass]] = [:]) async {
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
        let liveBySchedule = matcher.matchLiveAssets(assets: assets, schedules: schedules,
                                                     terms: terms,
                                                     makeupsBySchedule: makeupsBySchedule)

        // 手動追加写真（PHKit 同期 API）をバックグラウンドで解決
        let scheduleIDs = schedules.map { $0.id }
        let manualByID = await Task.detached(priority: .userInitiated) {
            var dict: [UUID: [PHAsset]] = [:]
            for id in scheduleIDs {
                dict[id] = PhotoInclusionStore.shared.fetchAssets(for: id)
            }
            return dict
        }.value

        // アルバムを構築（保存ONなら保存のみ写真もマージ）
        var built: [ClassAlbum] = []
        for schedule in schedules {
            let live = liveBySchedule[schedule.id] ?? []
            let manualLive = manualByID[schedule.id] ?? []
            guard !live.isEmpty || !manualLive.isEmpty || (schedule.savePhotosEnabled && savedStore.hasSavedPhotos(for: schedule.id)) else {
                continue
            }

            // 保存ファイルの localIdentifier → URL マップ
            let savedRecords = schedule.savePhotosEnabled ? savedStore.savedPhotos(for: schedule.id) : []
            let savedURLByID = Dictionary(savedRecords.map { ($0.localIdentifier, savedStore.fileURL(for: $0)) },
                                          uniquingKeysWith: { a, _ in a })

            // ライブ写真を AlbumPhoto に包む（保存があれば URL も付与）
            let livePhotos = live.map { AlbumPhoto(asset: $0, savedFileURL: savedURLByID[$0.localIdentifier]) }
            let manualPhotos = manualLive.map { AlbumPhoto(asset: $0, savedFileURL: savedURLByID[$0.localIdentifier]) }

            var albumAssets = livePhotos
            if schedule.savePhotosEnabled {
                // ライブにも手動にも無い保存写真＝写真アプリから削除済み → 保存のみとして追加
                let liveIDs = Set(live.map { $0.localIdentifier }).union(manualLive.map { $0.localIdentifier })
                let savedOnly = savedRecords
                    .filter { !liveIDs.contains($0.localIdentifier) }
                    .map { rec in
                        AlbumPhoto(id: rec.localIdentifier, creationDate: rec.creationDate,
                                   localIdentifier: rec.localIdentifier, asset: nil,
                                   savedFileURL: savedStore.fileURL(for: rec))
                    }
                albumAssets += savedOnly
            }

            var album = ClassAlbum(schedule: schedule, assets: albumAssets)
            album.manualAssets = manualPhotos
            album.makeupDates = (makeupsBySchedule[schedule.id] ?? []).map { $0.date }
            built.append(album)
        }
        albums = built.sorted { $0.schedule.subjectName < $1.schedule.subjectName }

        // 保存ONの授業について、未保存のマッチ写真をバックグラウンドで保存（UIをブロックしない）
        let toSaveSchedules = schedules.filter { $0.savePhotosEnabled }
        if !toSaveSchedules.isEmpty {
            var assetsToSave: [UUID: [PHAsset]] = [:]
            for schedule in toSaveSchedules {
                let candidates = (liveBySchedule[schedule.id] ?? []) + (manualByID[schedule.id] ?? [])
                if !candidates.isEmpty { assetsToSave[schedule.id] = candidates }
            }
            Task { await self.persistNewPhotos(assetsToSave) }
        }
    }

    // MARK: - 保存処理

    private func persistNewPhotos(_ assetsBySchedule: [UUID: [PHAsset]]) async {
        var didSaveAny = false
        for (scheduleID, assets) in assetsBySchedule {
            guard !savedStore.isInFlight(scheduleID) else { continue }
            savedStore.beginInFlight(scheduleID)
            defer { savedStore.endInFlight(scheduleID) }

            let alreadySaved = savedStore.savedLocalIdentifiers(for: scheduleID)
            for asset in assets where !alreadySaved.contains(asset.localIdentifier) {
                guard let data = await Self.encodedJPEG(for: asset,
                                                        maxDimension: maxSavedDimension,
                                                        quality: savedJPEGQuality) else { continue }
                let saved = await savedStore.save(imageData: data,
                                                  localIdentifier: asset.localIdentifier,
                                                  creationDate: asset.creationDate ?? Date(),
                                                  scheduleID: scheduleID)
                if saved { didSaveAny = true }
            }
        }
        // 実際に新規保存があった場合のみ、まとめてアルバムを更新通知（1枚ごとのループを防ぐ）
        if didSaveAny { savedStore.notifyChange() }
    }

    /// フル解像度を取得し、長辺キャップ＋JPEGエンコードしたデータを返す
    private static func encodedJPEG(for asset: PHAsset, maxDimension: CGFloat,
                                    quality: CGFloat) async -> Data? {
        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isSynchronous = false
            let resumed = ResumeGuard()
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { img, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded, resumed.markResumed() { continuation.resume(returning: img) }
            }
        }
        guard let image else { return nil }
        return await Task.detached(priority: .background) {
            let resized = Self.resize(image, maxDimension: maxDimension)
            return resized.jpegData(compressionQuality: quality)
        }.value
    }

    nonisolated private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
