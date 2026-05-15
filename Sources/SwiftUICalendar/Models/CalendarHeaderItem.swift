import SwiftUI
import Components

protocol CalendarHeaderItem: MenuPickerItem, Hashable, Identifiable where ID == Int {
}

struct MonthItem: CalendarHeaderItem {
  let id: Int
  let title: String
}

struct YearItem: CalendarHeaderItem {
  let id: Int
  let title: String
}
