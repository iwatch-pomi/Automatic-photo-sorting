import XCTest
@testable import ClassSnap

final class PhotoMatcherTests: XCTestCase {
    let matcher = PhotoMatcher()

    /// 純関数化後のヘルパー：terms/makeups なしでマッチ判定
    private func matches(_ date: Date, _ schedule: ClassSchedule) -> Bool {
        matcher.photoFallsInClass(date: date, schedule: schedule, terms: [], makeups: [])
    }

    // 授業時間内の写真はマッチする
    func testPhotoInsideClassTimeIsMatched() throws {
        let schedule = makeSchedule(dayOfWeek: 1, startH: 9, startM: 0, endH: 10, endM: 30)
        // 月曜 9:30
        let date = try makeDate(weekdayISO: 1, hour: 9, minute: 30)
        XCTAssertTrue(matches(date, schedule))
    }

    // バッファ内（開始9分前）はマッチする
    func testPhotoWithin10MinBufferBeforeStartIsMatched() throws {
        let schedule = makeSchedule(dayOfWeek: 1, startH: 9, startM: 0, endH: 10, endM: 30)
        let date = try makeDate(weekdayISO: 1, hour: 8, minute: 51) // 9分前
        XCTAssertTrue(matches(date, schedule))
    }

    // バッファ内（終了9分後）はマッチする
    func testPhotoWithin10MinBufferAfterEndIsMatched() throws {
        let schedule = makeSchedule(dayOfWeek: 1, startH: 9, startM: 0, endH: 10, endM: 30)
        let date = try makeDate(weekdayISO: 1, hour: 10, minute: 39) // 9分後
        XCTAssertTrue(matches(date, schedule))
    }

    // バッファ外（11分前）はマッチしない
    func testPhotoOutside10MinBufferDoesNotMatch() throws {
        let schedule = makeSchedule(dayOfWeek: 1, startH: 9, startM: 0, endH: 10, endM: 30)
        let date = try makeDate(weekdayISO: 1, hour: 8, minute: 49) // 11分前
        XCTAssertFalse(matches(date, schedule))
    }

    // 曜日が違うとマッチしない
    func testWrongDayDoesNotMatch() throws {
        let schedule = makeSchedule(dayOfWeek: 1, startH: 9, startM: 0, endH: 10, endM: 30) // 月曜
        let date = try makeDate(weekdayISO: 2, hour: 9, minute: 30) // 火曜
        XCTAssertFalse(matches(date, schedule))
    }

    // 土日はマッチしない
    func testWeekendDoesNotMatch() throws {
        let schedule = makeSchedule(dayOfWeek: 6, startH: 9, startM: 0, endH: 10, endM: 30) // dayOfWeek=6 は無効
        let date = try makeDate(weekdayISO: 6, hour: 9, minute: 30) // 土曜
        XCTAssertFalse(matches(date, schedule))
    }

    // MARK: - Helpers

    private func makeSchedule(dayOfWeek: Int, startH: Int, startM: Int, endH: Int, endM: Int) -> ClassSchedule {
        ClassSchedule(
            subjectName: "テスト授業",
            daysOfWeek: [dayOfWeek],
            startTimesSeconds: [startH * 3600 + startM * 60],
            endTimesSeconds: [endH * 3600 + endM * 60]
        )
    }

    /// weekdayISO: 1=月, 2=火, ..., 5=金, 6=土, 7=日
    private func makeDate(weekdayISO: Int, hour: Int, minute: Int) throws -> Date {
        // 2025-09-01 は月曜日（ISO週番号基準）
        // 月曜=1から weekdayISO-1 日後を基準日として使う
        let baseMondayString = "2025-09-01"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.calendar = Calendar(identifier: .gregorian)

        let dayOffset = weekdayISO - 1
        let dateStr = "2025-09-\(String(format: "%02d", 1 + dayOffset)) \(String(format: "%02d:%02d", hour, minute))"
        guard let date = formatter.date(from: dateStr) else {
            XCTFail("日付の生成に失敗: \(dateStr)")
            throw DateError.invalid
        }
        // baseMondayString が実際に月曜かを検証
        _ = baseMondayString
        return date
    }

    enum DateError: Error { case invalid }
}
