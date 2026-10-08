import SwiftUI
import SwiftData
import WidgetKit

struct ProfileView: View {
    let stores: AppStores
    @Bindable private var settings = AppSettings.shared
    @Bindable private var theme = ThemeManager.shared
    private let entitlement = EntitlementManager.shared
    @State private var showPaywall = false
    @State private var rewardLoading = false
    @State private var showRewardUnavailable = false
    // 隠しデベロッパーモード用：バージョン番号の連続タップ数と結果表示
    @State private var versionTapCount = 0
    @State private var showDevModeAlert = false

    /// リワード報酬による広告非表示の残り時間を「◯時間◯分」で表す（有効時のみ）。
    private var rewardRemainingText: String? {
        let remaining = settings.rewardAdFreeRemaining
        guard remaining > 0 else { return nil }
        let totalMinutes = Int(remaining / 60) + 1  // 端数は切り上げ
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 { return "あと約\(h)時間\(m)分" }
        return "あと約\(m)分"
    }

    // 授業一覧は ScheduleStore を単一情報源として参照（独自 FetchDescriptor の二重取得を撤去）
    private var schedules: [ClassSchedule] { stores.schedule.schedules }

    /// Info.plist の CFBundleShortVersionString からバージョンを取得し、表示を常に最新に保つ
    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "v\($0)" } ?? "—"
    }

    private var lunchBreakStartBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(secondsFromMidnight: settings.lunchBreakStartSeconds) },
            set: { settings.lunchBreakStartSeconds = Calendar.current.secondsFromMidnight(for: $0) }
        )
    }

    private var lunchBreakEndBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(secondsFromMidnight: settings.lunchBreakEndSeconds) },
            set: { settings.lunchBreakEndSeconds = Calendar.current.secondsFromMidnight(for: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: entitlement.isAdFree ? "checkmark.seal.fill" : "rectangle.slash.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.appGreen)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entitlement.isAdFree ? "広告非表示（購入済み）" : "広告を非表示にする")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text(entitlement.isAdFree
                                         ? "広告は表示されません。応援ありがとうございます！"
                                         : "すべての機能は無料。買い切り／サブスクで広告を消して快適に利用できます")
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if !entitlement.isAdFree {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Color.appGreen)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // 未課金ユーザー向け：動画を見て6時間だけ無料で広告を消す導線（リワード広告）
                        if !entitlement.isAdFree {
                            Button {
                                guard !rewardLoading else { return }
                                rewardLoading = true
                                AdManager.shared.showRewardedForAdFree(
                                    onReward: { rewardLoading = false },
                                    onUnavailable: { rewardLoading = false; showRewardUnavailable = true }
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    if rewardLoading {
                                        ProgressView().frame(width: 24)
                                    } else {
                                        Image(systemName: "play.rectangle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Color.appGreen)
                                            .frame(width: 24)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("動画を見て6時間広告を消す")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(Color.appTextPrimary)
                                        Text(rewardRemainingText.map { "広告非表示中（\($0)）。もう一度見ると延長できます" }
                                             ?? "無料。動画広告を最後まで見ると6時間 広告が表示されなくなります")
                                            .font(.caption)
                                            .foregroundStyle(rewardRemainingText != nil ? Color.appGreen : Color.appTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("プラン")
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("メインの色")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextPrimary)
                            // 全色をひと目で見渡せるよう、横スクロールではなく折り返しグリッドで並べる
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                                spacing: 12
                            ) {
                                ForEach(AppThemePreset.presets) { preset in
                                    let isSel = theme.themeColorID == preset.id
                                    VStack(spacing: 5) {
                                        Circle()
                                            .fill(preset.accent)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle().strokeBorder(Color.appTextPrimary.opacity(0.15),
                                                                      lineWidth: 1)
                                            )
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.caption).fontWeight(.bold)
                                                    .foregroundStyle(preset.onAccent)
                                                    .opacity(isSel ? 1 : 0)
                                            )
                                            .overlay(
                                                Circle().strokeBorder(Color.appTextPrimary.opacity(0.6),
                                                                      lineWidth: isSel ? 2 : 0)
                                            )
                                        Text(preset.name)
                                            .font(.caption2)
                                            .foregroundStyle(isSel ? Color.appGreen : Color.appTextSecondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                    .onTapGesture { theme.themeColorID = preset.id }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.vertical, 4)

                        Picker("背景", selection: $theme.useWhiteBackground) {
                            Text("ベージュ").tag(false)
                            Text("白").tag(true)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("テーマ")
                    } footer: {
                        Text("アプリのメインの色と背景を変更できます。薄い色を選んでも、文字が読みやすいよう自動で調整されます。")
                            .font(.caption)
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        HStack {
                            Image(systemName: "clock.badge")
                                .foregroundStyle(Color.appGreen)
                                .frame(width: 24)
                            Text("バッファ時間")
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Stepper(
                                "±\(settings.bufferMinutes)分",
                                value: $settings.bufferMinutes,
                                in: 0...60,
                                step: 1
                            )
                            .fixedSize()
                            .foregroundStyle(Color.appTextSecondary)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("バッファ時間とは？", systemImage: "questionmark.circle")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(Color.appGreen)
                            Text("""
                                授業の開始・終了時刻の前後に「ゆとり」を持たせて写真を探す機能です。

                                例）バッファ±10分・授業が9:00〜10:30の場合
                                → **8:50〜10:40** の間に撮影された写真を取得します。

                                授業ギリギリに撮り忘れた写真や、終了後すぐに撮った写真も拾えるように設定してください。0分にするとぴったりの時間帯だけを対象にします。
                                """)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("アプリ設定")
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        DatePicker(
                            "休憩開始",
                            selection: lunchBreakStartBinding,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "休憩終了",
                            selection: lunchBreakEndBinding,
                            displayedComponents: .hourAndMinute
                        )
                        if settings.lunchBreakStartSeconds >= settings.lunchBreakEndSeconds {
                            Label("終了は開始より後に設定してください",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("デフォルト昼休み時間")
                    } footer: {
                        Text("授業登録時に「昼休み除外」をオンにした際のデフォルト値として使われます")
                            .font(.caption)
                    }
                    .listRowBackground(Color.appCard)

                    Section("コマの設定") {
                        NavigationLink(destination: PeriodManagementView()) {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                    .foregroundStyle(Color.appGreen)
                                    .frame(width: 24)
                                Text("コマ時間を管理")
                                    .foregroundStyle(Color.appTextPrimary)
                                Spacer()
                                let count = ClassPeriodStore.shared.periods.count
                                if count > 0 {
                                    Text("\(count)コマ")
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section("学期の設定") {
                        NavigationLink(destination: TermManagementView(stores: stores)) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color.appGreen)
                                    .frame(width: 24)
                                Text("学期を管理")
                                    .foregroundStyle(Color.appTextPrimary)
                                Spacer()
                                if let current = stores.term.currentTerm {
                                    Text(current.name)
                                        .foregroundStyle(Color.appTextSecondary)
                                } else if !stores.term.terms.isEmpty {
                                    Text("\(stores.term.terms.count)学期")
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section("写真管理") {
                        NavigationLink(destination: ExcludedPhotosView(schedules: schedules)) {
                            HStack {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(Color.appGreen)
                                    .frame(width: 24)
                                Text("除外した写真")
                                    .foregroundStyle(Color.appTextPrimary)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)

                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.appGreen)
                                .frame(width: 24)
                            Text("バージョン")
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text(appVersionString)
                                .foregroundStyle(Color.appTextSecondary)
                                // 隠しデベロッパーモード：5回タップで「課金中でも広告表示」を切り替え
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    versionTapCount += 1
                                    if versionTapCount >= 5 {
                                        versionTapCount = 0
                                        settings.adTestModeEnabled.toggle()
                                        if settings.adTestModeEnabled {
                                            AdManager.shared.preloadInterstitial()
                                        }
                                        showDevModeAlert = true
                                    }
                                }
                        }
                    } header: {
                        Text("情報")
                    } footer: {
                        Text("時間割や各種設定は、この端末内にのみ保存されます。アプリを削除すると、登録した時間割・学期・コマ・補講・テスト範囲などのデータはすべて消去されます（写真アプリ内の写真は影響を受けません）。")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .listRowBackground(Color.appCard)

                    // デベロッパーモード（バージョン5回タップでON）中のみ表示するテスト用セクション
                    if settings.adTestModeEnabled {
                        Section {
                            Button {
                                AdManager.shared.showTestInterstitial()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.inset.filled")
                                        .foregroundStyle(Color.appGreen).frame(width: 24)
                                    Text("全画面広告をテスト表示")
                                        .foregroundStyle(Color.appTextPrimary)
                                }
                            }
                            Button {
                                AdManager.shared.showTestRewarded()
                            } label: {
                                HStack {
                                    Image(systemName: "play.rectangle.on.rectangle.fill")
                                        .foregroundStyle(Color.appGreen).frame(width: 24)
                                    Text("リワード広告をテスト表示")
                                        .foregroundStyle(Color.appTextPrimary)
                                }
                            }
                            if settings.isRewardAdFreeActive {
                                Button(role: .destructive) {
                                    settings.rewardAdFreeUntil = 0
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .frame(width: 24)
                                        Text("リワード報酬（広告非表示）をリセット")
                                    }
                                }
                            }
                        } header: {
                            Text("デベロッパー")
                        } footer: {
                            Text("テスト用の広告を即座に表示します（デベロッパーモード中のみ）。リワード広告を最後まで見ると、本番同様に6時間 広告が非表示になります。")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .listRowBackground(Color.appCard)
                    }
                }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("設定")
                        .font(.headline).foregroundStyle(Color.appTextPrimary)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            // テーマ変更をホーム画面ウィジェットにも反映
            .onChange(of: theme.themeColorID) { WidgetCenter.shared.reloadAllTimelines() }
            .onChange(of: theme.useWhiteBackground) { WidgetCenter.shared.reloadAllTimelines() }
            .alert("動画広告を準備中です", isPresented: $showRewardUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ただいま動画広告を読み込めませんでした。通信環境をご確認のうえ、少し時間をおいて再度お試しください。")
            }
            .alert(settings.adTestModeEnabled ? "デベロッパーモード: ON" : "デベロッパーモード: OFF",
                   isPresented: $showDevModeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(settings.adTestModeEnabled
                     ? "課金中でも広告を表示します（動作確認用）。もう一度バージョンを5回タップすると解除できます。"
                     : "通常の表示に戻りました。")
            }
        }
    }
}
