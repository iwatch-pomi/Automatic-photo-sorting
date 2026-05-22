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
                    SessionRowCard(
                        session: session,
                        customTitle: customTitle,
                        onRename: {
                            editingSessionID = session.id
                            editingTitle = customTitle ?? session.displayTitle
                        },
                        onReset: customTitle != nil ? {
                            titleStore.removeTitle(for: session.id)
                        } : nil
                    )
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
        }
    }
}

private struct SessionRowCard: View {
    let session: SessionAlbum
    let customTitle: String?
    let onRename: () -> Void
    let onReset: (() -> Void)?

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

            Menu {
                Button {
                    onRename()
                } label: {
                    Label("名前を変更", systemImage: "pencil")
                }

                if let onReset {
                    Button(role: .destructive) {
                        onReset()
                    } label: {
                        Label("名前をリセット", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .simultaneousGesture(TapGesture())
        }
        .padding(.vertical, 4)
    }
}
