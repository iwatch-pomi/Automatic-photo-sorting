import SwiftUI
import Photos

struct SessionListView: View {
    let album: ClassAlbum

    private var sessions: [SessionAlbum] { album.sessionAlbums() }
    private let titleStore = SessionTitleStore.shared

    @State private var editingSessionID: String?
    @State private var editingTitle: String = ""

    var body: some View {
        List {
            ForEach(sessions) { session in
                let customTitle = titleStore.title(for: session.id)
                NavigationLink(destination: PhotoGridView(session: session)) {
                    SessionRowCard(session: session, customTitle: customTitle)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        editingSessionID = session.id
                        editingTitle = customTitle ?? session.displayTitle
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }
                    .tint(Color.appGreen)

                    if customTitle != nil {
                        Button(role: .destructive) {
                            titleStore.removeTitle(for: session.id)
                        } label: {
                            Label("リセット", systemImage: "arrow.uturn.backward")
                        }
                    }
                }
            }
            .listRowBackground(Color.appCard)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(album.schedule.subjectName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("セッション名を変更", isPresented: Binding(
            get: { editingSessionID != nil },
            set: { if !$0 { editingSessionID = nil } }
        )) {
            TextField("セッション名", text: $editingTitle)
            Button("保存") {
                if let id = editingSessionID {
                    titleStore.setTitle(editingTitle, for: id)
                }
                editingSessionID = nil
            }
            Button("キャンセル", role: .cancel) {
                editingSessionID = nil
            }
        } message: {
            Text("左スワイプで変更、リセットで元の名前に戻せます")
        }
    }
}

private struct SessionRowCard: View {
    let session: SessionAlbum
    let customTitle: String?

    private var displayTitle: String { customTitle ?? session.displayTitle }

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(asset: session.assets.first, size: CGSize(width: 120, height: 90))
                .frame(width: 80, height: 60)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(displayTitle)
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)
                    if customTitle != nil {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appGreen.opacity(0.8))
                    }
                }

                if !session.dateRangeDisplay.isEmpty {
                    Text(session.dateRangeDisplay)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appGreen)
                    Text("\(session.assets.count)枚")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
