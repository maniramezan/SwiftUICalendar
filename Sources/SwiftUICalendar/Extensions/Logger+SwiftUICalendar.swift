import Foundation
import OSLog
import SwiftCommons

// MARK: - SwiftUICalendar Subsystem

extension Logger {

    /// The subsystem identifier for SwiftUICalendar package
    private static let swiftUICalendarSubsystem = "SwiftUICalendar"

    // MARK: Convenience Factory Methods

    /// Creates a logger for SwiftUICalendar with automatic category
    /// - Parameter type: The type to use for category derivation
    /// - Returns: Logger configured for SwiftUICalendar
    ///
    /// Usage:
    /// ```swift
    /// private let logger = Logger.swiftUICalendar(for: Self.self)
    /// // Category will be derived from the type (e.g., "CalendarViewModel")
    /// ```
    public static func swiftUICalendar(for type: Any.Type) -> Logger {
        Logger.forType(subsystem: swiftUICalendarSubsystem, type)
    }

    /// Creates a logger for SwiftUICalendar with automatic category from caller
    /// - Parameter file: The file path (automatically filled by compiler)
    /// - Returns: Logger configured for SwiftUICalendar
    ///
    /// Usage:
    /// ```swift
    /// private let logger = Logger.swiftUICalendar()
    /// // Category will be derived from the filename
    /// ```
    public static func swiftUICalendar(file: String = #file) -> Logger {
        Logger.forCaller(subsystem: swiftUICalendarSubsystem, file: file)
    }

    // MARK: Pre-configured Common Loggers

    /// Logger for view lifecycle and rendering events
    ///
    /// Usage:
    /// ```swift
    /// Logger.calendarUI.debug("Rendering calendar grid")
    /// ```
    public static let calendarUI = Logger(
        subsystem: swiftUICalendarSubsystem,
        category: "UI"
    )

    /// Logger for date calculations and calendar logic
    ///
    /// Usage:
    /// ```swift
    /// Logger.calendarLogic.info("Calculating month boundaries")
    /// ```
    public static let calendarLogic = Logger(
        subsystem: swiftUICalendarSubsystem,
        category: "Logic"
    )

    /// Logger for user interactions (selection, navigation)
    ///
    /// Usage:
    /// ```swift
    /// Logger.calendarInteraction.info("User selected date range")
    /// ```
    public static let calendarInteraction = Logger(
        subsystem: swiftUICalendarSubsystem,
        category: "Interaction"
    )

    /// Logger for theme and configuration changes
    ///
    /// Usage:
    /// ```swift
    /// Logger.calendarConfiguration.debug("Theme updated")
    /// ```
    public static let calendarConfiguration = Logger(
        subsystem: swiftUICalendarSubsystem,
        category: "Configuration"
    )
}
