import SwiftUI

/// アップデート後に一度だけ表示する「お知らせ」ポップアップ。
/// 内容を変えて再度全ユーザーに出したいときは `currentID` を更新する
/// （AppSettings.whatsNewSeenID と一致しない場合のみ表示される）。
struct WhatsNewView: View {
    /// このお知らせの識別子。値を変えると全ユーザーに再度1回表示される。
    static let currentID = "whatsnew_widget_free_v1"

    let onClose: () -> Void

    private struct Item { let icon: String; let title: String; let body: String }

    private let items: [Item] = [
        Item(icon: "rectangle.3.group.fill",
             title: "ホーム画面ウィジェットを追加しました",
             body: "今日の時間割をホーム画面でひと目で確認できます。「次の授業までのカウントダウン」付きで、次のコマまであと何分かがすぐわかります。ホーム画面を長押し →「＋」→「コマフォト」で追加してください。"),
        Item(icon: "gift.fill",
             title: "すべての機能が無料になりました",
             body: "写真・PDFの書き出し、アプリ内保存、テスト範囲マーカー、複数学期の管理などを、すべて無料でご利用いただけます。広告を非表示にしたい方向けに、買い切り／サブスクもご用意しています。"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
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

                    VStack(spacing: 16) {
                        ForEach(items.indices, id: \.self) { i in
                            let item = items[i]
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
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }

            Button(action: onClose) {
                Text("はじめる")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.appBackground)
        // ボタンで閉じさせて「既読」を確実に記録する（スワイプで閉じさせない）
        .interactiveDismissDisabled(true)
    }
}
