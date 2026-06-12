import OSLog
import Testing

@testable import SwiftUICalendar

@Suite("Logger Tests")
struct LoggerTests {

  @Test("Logger factories create package loggers")
  func loggerFactoriesCreatePackageLoggers() {
    _ = Logger.swiftUICalendar(for: LoggerTests.self)
    _ = Logger.swiftUICalendar(file: #file)
    _ = Logger.calendarUI
    _ = Logger.calendarLogic
    _ = Logger.calendarInteraction
    _ = Logger.calendarConfiguration
  }
}
