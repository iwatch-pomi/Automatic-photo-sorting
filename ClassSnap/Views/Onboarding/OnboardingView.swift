import SwiftUI

/// 初回起動時のみ表示するオンボーディング。
/// コマ時間と学期の設定をユーザーに促す。
struct OnboardingView: View {
    let stores: AppStores
    let onComplete: () -> Void

    @State private var periodStore = ClassPeriodStore.shared
    @State private var showIntro = true

    private var hasPeriods: Bool { periodStore.hasPeriods }
    private var hasTerms: Bool { !stores.term.terms.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if showIntro {
                    introPage
                } else {
                    setupPage
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Intro page（使い方の紹介）

    private var introPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.appGreen)
                    Text("ようこそ コマフォト へ")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)
                    Text("コマフォトでできることを\nかんたんにご紹介します。")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
                    featureRow(
                        icon: "camera.fill",
                        title: "撮るだけで、授業ごとに自動整理",
                        description: "授業中に写真を撮るだけ。撮影した時刻をもとに、写真が自動で授業ごとのアルバムに振り分けられます。")
                    featureRow(
                        icon: "square.grid.2x2.fill",
                        title: "ホーム画面ウィジェット",
                        description: "今日の時間割と「次の授業までのカウントダウン」を、ホーム画面でひと目で確認できます。")
                    featureRow(
                        icon: "lock.fill",
                        title: "写真は端末内で処理",
                        description: "写真の解析・振り分けはすべて端末内で完結し、外部に送信されません。安心してお使いいただけます。")
                    featureRow(
                        icon: "eye.slash.fill",
                        title: "不要な写真は除外できる",
                        description: "授業時間にたまたま撮った関係のない写真が混ざっても、アルバムから簡単に除外できます。")
                }

                Button {
                    showIntro = false
                } label: {
                    Text("次へ")
                        .font(.headline)
                        .foregroundStyle(Color.appOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.appGreen)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Setup page（初期設定）

    private var setupPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 14) {
                        NavigationLink {
                            PeriodManagementView()
                        } label: {
                            stepCard(
                                number: 1,
                                title: "コマ時間を設定",
                                description: "1コマ目・2コマ目…の時間帯を登録すると、授業をコマ単位ですばやく登録できます。",
                                systemImage: "clock.badge.checkmark",
                                done: hasPeriods
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            TermManagementView(stores: stores)
                        } label: {
                            stepCard(
                                number: 2,
                                title: "学期を設定",
                                description: "前期・後期や1T〜4Tなどの学期を登録すると、学期ごとに写真を正しく振り分けられます。",
                                systemImage: "calendar.badge.clock",
                                done: hasTerms
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("どちらも後から「設定」画面でいつでも変更できます。")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)

                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.appGreen)
            Text("ようこそ コマフォト へ")
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("授業の板書写真を自動で振り分けるために、\nまず2つの設定をしましょう。")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Step card

    private func stepCard(number: Int, title: String, description: String,
                          systemImage: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color.appGreen : Color.appGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.appOnAccent)
                } else {
                    Text("\(number)")
                        .font(.headline).fontWeight(.bold)
                        .foregroundStyle(Color.appGreen)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(Color.appGreen)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    if done {
                        Text("設定済み")
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(Color.appOnAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.appGreen)
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            onComplete()
        } label: {
            Text((hasPeriods && hasTerms) ? "アプリを始める" : "この設定で始める")
                .font(.headline)
                .foregroundStyle(Color.appOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 4)
    }
}
