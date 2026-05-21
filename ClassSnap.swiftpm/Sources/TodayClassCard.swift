import SwiftUI

struct TodayClassCard: View {
    let schedule: ClassSchedule
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(schedule.startTimeDisplay) - \(schedule.endTimeDisplay)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appTextSecondary)

                Text(schedule.className)
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
