import SwiftUI
import Photos
import UIKit

struct PhotoDetailView: View {
    let photos: [AlbumPhoto]
    let initialPhoto: AlbumPhoto
    var firstClassDate: Date?
    var daysOfWeek: [Int] = []
    var makeupDates: [Date] = []

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var shareItems: [Any]?
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        FullResolutionImageView(photo: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.black)
                .ignoresSafeArea(edges: .top)

                // 全画面写真の下にもバナー広告を表示（課金・インストール猶予・報酬中は非表示）
                if AdManager.adsVisible {
                    BannerAdView()
                        .frame(height: BannerAdView.adaptiveSize.size.height)
                        .frame(maxWidth: .infinity)
                        .background(Color.appBackground)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .tint(.white)
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        if currentIndex < photos.count {
                            let photo = photos[currentIndex]
                            if let fcd = firstClassDate,
                               let number = photo.sessionNumber(firstClassDate: fcd, daysOfWeek: daysOfWeek, makeupDates: makeupDates) {
                                Text("第\(number)回")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Text(photo.creationDateDisplay)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isExporting {
                        ProgressView().tint(.white)
                    } else {
                        Button {
                            Task { await shareCurrentPhoto() }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .tint(.white)
                        }
                    }
                }
            }
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } }
            )) {
                if let items = shareItems {
                    ShareSheet(items: items)
                }
            }
        }
        .onAppear {
            if let idx = photos.firstIndex(where: { $0.id == initialPhoto.id }) {
                currentIndex = idx
            }
        }
    }

    private func shareCurrentPhoto() async {
        guard currentIndex < photos.count else { return }
        isExporting = true
        defer { isExporting = false }

        if let image = await photos[currentIndex].loadFullImage() {
            shareItems = [image]
        }
    }
}
