import Components
import SwiftUI

protocol CalendarHeaderItem: MenuPickerItem, Hashable, Identifiable where ID == Int {
}

struct MonthItem: CalendarHeaderItem {
  let id: Int
  let title: String
  var month: MonthIdentifier? = nil
}

struct YearItem: CalendarHeaderItem {
  let id: Int
  let title: String
}
