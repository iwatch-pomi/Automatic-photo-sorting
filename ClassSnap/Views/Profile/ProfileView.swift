import SwiftUI
import SwiftData

struct ProfileView: View {
    let stores: AppStores
    @Bindable private var settings = AppSettings.shared
    private let entitlement = EntitlementManager.shared
    @State private var showPaywall = false

    // 授業一覧は ScheduleStore を単一情報源として参照（独自 FetchDescriptor の二重取得を撤去）
    private var schedules: [ClassSchedule] { stores.schedule.schedules }

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
                                Image(systemName: "crown.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.appGreen)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entitlement.isPro ? "板書っと Pro 利用中" : "板書っと Pro にアップグレード")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text(entitlement.isPro
                                         ? "すべての機能をご利用いただけます。ありがとうございます！"
                                         : "写真のアプリ内保存・PDF書き出し・テスト範囲などProの機能を確認できます")
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if !entitlement.isPro {
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
                    } header: {
                        Text("プラン")
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
                                step: 5
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
                            Text("1.0.0 MVP")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    } header: {
                        Text("情報")
                    } footer: {
                        Text("時間割や各種設定は、この端末内にのみ保存されます。アプリを削除すると、登録した時間割・学期・コマ・補講・テスト範囲などのデータはすべて消去されます（写真アプリ内の写真は影響を受けません）。")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .listRowBackground(Color.appCard)
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
        }
    }
}
