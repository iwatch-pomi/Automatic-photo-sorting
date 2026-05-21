import Photos
import Foundation

final class PhotoLibraryService {

    func requestAuthorization() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func fetchAssets(from startDate: Date, to endDate: Date) -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@ AND mediaType == %d",
            startDate as NSDate,
            endDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func defaultDateRange(isPremium: Bool = false) -> (start: Date, end: Date) {
        let end = Date()
        let days = isPremium ? -365 : -7
        let start = Calendar.current.date(byAdding: .day, value: days, to: end)!
        return (start, end)
    }
}
