import SwiftCommons
import SwiftUI

struct CalendarWeekHeaderView: View {
    @Environment(\.calendarMetrics) private var metrics

    @State var weekDays: [String]

    var body: some View {
        HStack(spacing: metrics.itemSpacing) {
            ForEach(weekDays, id: \.self) { day in
                ZStack {
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.03)
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, metrics.tightPadding)
        .adaptiveGlass(shape: .roundedRectangle(cornerRadius: metrics.cornerRadius))
    }
}

#Preview {
    CalendarWeekHeaderView(
        weekDays: CalendarViewModel.test(identifier: .persian).headerTitles)
}
