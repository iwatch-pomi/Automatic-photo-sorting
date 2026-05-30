import SwiftUI

struct TodayClassCard: View {
    let schedule: ClassSchedule
    let day: Int
    let isSelected: Bool
    let onTap: () -> Void

    private func fmt(_ s: Int) -> String { String(format: "%02d:%02d", s / 3600, (s % 3600) / 60) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(fmt(schedule.startTime(for: day))) - \(fmt(schedule.endTime(for: day)))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appTextSecondary)

                Text(schedule.subjectName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !schedule.room.isEmpty {
                    Text("(\(schedule.room))")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(width: 120, alignment: .leading)
            .padding(10)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
