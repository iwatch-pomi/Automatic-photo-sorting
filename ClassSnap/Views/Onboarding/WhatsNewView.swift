import SwiftUI

/// アップデート後に一度だけ表示する「お知らせ」ポップアップ。
/// 最新のアップデートに加えて、これまでのアップデート履歴も表示する。
/// 内容を変えて再度全ユーザーに出したいときは `currentID` を更新する
/// （AppSettings.whatsNewSeenID と一致しない場合のみ表示される）。
struct WhatsNewView: View {
    /// このお知らせの識別子。値を変えると全ユーザーに再度1回表示される。
    static let currentID = "whatsnew_skyblue_v3"

    let onClose: () -> Void

    private struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }
    private struct Release: Identifiable {
        let id = UUID()
        let heading: String
        let items: [Item]
    }

    /// 最新のアップデート（今回の目玉）
    private let latest = Release(
        heading: "メインカラーを水色に一新しました",
        items: [
            Item(icon: "drop.fill",
                 title: "アプリのメインカラーを水色に変更",
                 body: "コマフォトの新しいイメージカラーとして水色を採用しました。アプリのアイコンも水色に新しくなりました。"),
            Item(icon: "paintbrush.fill",
                 title: "色・背景はいつでも変えられます",
                 body: "設定の「テーマ」「アプリのアイコン」から、お好みの色や背景（白／ベージュ）に変更できます。これまでの緑もお選びいただけます。"),
        ]
    )

    /// これまでのアップデート（新しい順）
    private let past: [Release] = [
        Release(
            heading: "テーマカラーを選べるようになりました",
            items: [
                Item(icon: "paintpalette.fill",
                     title: "メインの色を10色から選べます",
                     body: "設定の「テーマ」から、アプリのメインの色を10色（水色・ミント・ラベンダーなどの淡い色も）に変更できます。"),
                Item(icon: "circle.lefthalf.filled",
                     title: "背景色をベージュ／白から選べます",
                     body: "背景を、淡いベージュか白のどちらかに切り替えられます。"),
                Item(icon: "square.grid.2x2.fill",
                     title: "ウィジェットの色も変わります",
                     body: "選んだメインの色は、ホーム画面ウィジェットの配色にも反映されます。"),
            ]
        ),
        Release(
            heading: "ホーム画面ウィジェットと全機能無料化",
            items: [
                Item(icon: "rectangle.3.group.fill",
                     title: "ホーム画面ウィジェットを追加",
                     body: "今日の時間割と「次の授業までのカウントダウン」をホーム画面でひと目で確認できます。"),
                Item(icon: "gift.fill",
                     title: "すべての機能が無料に",
                     body: "写真・PDFの書き出し、アプリ内保存、テスト範囲マーカー、複数学期の管理などをすべて無料でご利用いただけます。広告を消したい方向けに買い切り／サブスクもご用意しています。"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    // 最新のアップデート
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("新着", highlighted: true)
                        Text(latest.heading)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.horizontal, 4)
                        VStack(spacing: 16) {
                            ForEach(latest.items) { itemCard($0) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // これまでのアップデート
                    if !past.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionLabel("これまでのアップデート", highlighted: false)
                            ForEach(past) { release in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(release.heading)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .padding(.horizontal, 4)
                                    VStack(spacing: 16) {
                                        ForEach(release.items) { itemCard($0) }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }

            Button(action: onClose) {
                Text("はじめる")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appGreen)
                    .foregroundStyle(Color.appOnAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.appBackground)
        // ボタンで閉じさせて「既読」を確実に記録する（スワイプで閉じさせない）
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Color.appGreen)
                .padding(.top, 28)
            Text("アップデートのお知らせ")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("コマフォトが新しくなりました")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func sectionLabel(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.caption).fontWeight(.bold)
            .foregroundStyle(highlighted ? Color.appOnAccent : Color.appTextSecondary)
            .padding(.horizontal, highlighted ? 10 : 0).padding(.vertical, highlighted ? 4 : 0)
            .background(highlighted ? Color.appGreen : Color.clear)
            .clipShape(Capsule())
    }

    private func itemCard(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(Color.appGreen)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
