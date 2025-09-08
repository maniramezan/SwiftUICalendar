import SwiftUI

struct CalendarWeekHeaderView: View {

    @State var weekDays: [String]

    var body: some View {
        HStack(spacing: 8) {
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
        .padding(.vertical, 4)
        .adaptiveGlass(shape: .roundedRectangle(cornerRadius: 8))
    }
}

import SwiftCommons

#Preview {
    CalendarWeekHeaderView(
        weekDays: CalendarViewModel.test(identifier: .persian).headerTitles)
}
