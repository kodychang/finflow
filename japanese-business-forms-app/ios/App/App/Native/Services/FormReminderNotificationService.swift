import Foundation
import UserNotifications

extension Notification.Name {
    static let shokoFormsOpenReminderDocument = Notification.Name("shokoFormsOpenReminderDocument")
}

struct FormReminderNotificationSettings {
    static let enabledKey = "native.shokoForms.formReminderNotificationsEnabled.v1"
    static let leadDaysKey = "native.shokoForms.formReminderLeadDays.v1"
    static let adjustForJapanHolidaysKey = "native.shokoForms.formReminderAdjustForJapanHolidays.v1"

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var leadDays: Int {
        if UserDefaults.standard.object(forKey: Self.leadDaysKey) == nil {
            return 1
        }
        return max(0, min(UserDefaults.standard.integer(forKey: Self.leadDaysKey), 30))
    }

    var adjustsForJapanHolidays: Bool {
        if UserDefaults.standard.object(forKey: Self.adjustForJapanHolidaysKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.adjustForJapanHolidaysKey)
    }
}

final class FormReminderNotificationService {
    static let shared = FormReminderNotificationService()

    static let formReminderCategoryIdentifier = "SHOKO_FORM_REMINDER"
    static let externalImportCategoryIdentifier = "SHOKO_EXTERNAL_IMPORT"
    static let openActionIdentifier = "OPEN_SHOKO"

    private static let notificationPrefix = "shoko.formReminder."
    private let calendar: Calendar

    private init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        self.calendar = calendar
    }

    func registerNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: Self.openActionIdentifier,
            title: "Shoko を開く",
            options: [.foreground]
        )
        let formCategory = UNNotificationCategory(
            identifier: Self.formReminderCategoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        let importCategory = UNNotificationCategory(
            identifier: Self.externalImportCategoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([formCategory, importCategory])
    }

    func requestAuthorizationAndReschedule(documents: [BusinessDocument]) {
        registerNotificationCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] isGranted, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if isGranted {
                    self.rescheduleAll(for: documents)
                } else {
                    self.cancelAll()
                }
            }
        }
    }

    func rescheduleAll(for documents: [BusinessDocument]) {
        let settings = FormReminderNotificationSettings()
        guard settings.isEnabled else {
            cancelAll()
            return
        }

        registerNotificationCategories()
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] notificationSettings in
            guard let self else { return }
            guard notificationSettings.authorizationStatus == .authorized || notificationSettings.authorizationStatus == .provisional else {
                return
            }

            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { pendingRequests in
                let staleIdentifiers = pendingRequests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(Self.notificationPrefix) }
                center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
                let requests = documents.compactMap { self.notificationRequest(for: $0, settings: settings) }
                requests.forEach { center.add($0) }
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.notificationPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func cancel(documentIDs: Set<BusinessDocument.ID>) {
        let identifiers = documentIDs.map { Self.notificationIdentifier(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func pendingDocumentID(from response: UNNotificationResponse) -> UUID? {
        guard response.notification.request.content.categoryIdentifier == formReminderCategoryIdentifier,
              let rawValue = response.notification.request.content.userInfo["documentID"] as? String
        else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    static func notificationIdentifier(for documentID: BusinessDocument.ID) -> String {
        "\(notificationPrefix)\(documentID.uuidString)"
    }

    private func notificationRequest(for document: BusinessDocument, settings: FormReminderNotificationSettings) -> UNNotificationRequest? {
        guard !document.type.isAttachmentRecord,
              let triggerDate = reminderDate(for: document, settings: settings),
              triggerDate > Date()
        else {
            return nil
        }

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: document)
        content.body = reminderBody(for: document)
        content.sound = .default
        content.categoryIdentifier = Self.formReminderCategoryIdentifier
        content.userInfo = ["documentID": document.id.uuidString]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: Self.notificationIdentifier(for: document.id),
            content: content,
            trigger: trigger
        )
    }

    private func reminderDate(for document: BusinessDocument, settings: FormReminderNotificationSettings) -> Date? {
        guard let baseDate = reminderBaseDate(for: document) else { return nil }
        let rawDate = calendar.date(byAdding: .day, value: -settings.leadDays, to: baseDate) ?? baseDate
        let adjustedDay = settings.adjustsForJapanHolidays ? previousBusinessDay(from: rawDate) : rawDate
        var components = calendar.dateComponents([.year, .month, .day], from: adjustedDay)
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components)
    }

    private func reminderBaseDate(for document: BusinessDocument) -> Date? {
        switch document.type {
        case .receipt, .vendorReceipt, .acceptance:
            return document.transactionDate
        default:
            return document.dueDate
        }
    }

    private func reminderTitle(for document: BusinessDocument) -> String {
        switch document.type {
        case .receipt, .vendorReceipt, .acceptance:
            return "入帳日提醒"
        default:
            return "支払日提醒"
        }
    }

    private func reminderBody(for document: BusinessDocument) -> String {
        let partner = document.customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = document.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = number.isEmpty ? document.type.title : "\(document.type.title) \(number)"
        return partner.isEmpty ? "\(title) の予定日が近づいています。" : "\(partner) / \(title) の予定日が近づいています。"
    }

    private func previousBusinessDay(from date: Date) -> Date {
        var day = calendar.startOfDay(for: date)
        while isWeekend(day) || JapaneseHolidayCalendar.isHoliday(day, calendar: calendar) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return day
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

enum JapaneseHolidayCalendar {
    static func isHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: date)
        return holidays(for: year, calendar: calendar).contains(calendar.startOfDay(for: date))
    }

    static func holidays(for year: Int, calendar: Calendar) -> Set<Date> {
        var holidays = Set<Date>()
        func add(_ month: Int, _ day: Int) {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                holidays.insert(calendar.startOfDay(for: date))
            }
        }
        func addMonday(_ month: Int, _ ordinal: Int) {
            if let date = nthWeekday(year: year, month: month, weekday: 2, ordinal: ordinal, calendar: calendar) {
                holidays.insert(date)
            }
        }

        add(1, 1)
        addMonday(1, 2)
        add(2, 11)
        add(2, 23)
        add(3, vernalEquinoxDay(year))
        add(4, 29)
        add(5, 3)
        add(5, 4)
        add(5, 5)
        addMonday(7, 3)
        add(8, 11)
        addMonday(9, 3)
        add(9, autumnalEquinoxDay(year))
        addMonday(10, 2)
        add(11, 3)
        add(11, 23)

        holidays.formUnion(substituteHolidays(for: holidays, calendar: calendar))
        holidays.formUnion(citizensHolidays(for: holidays, year: year, calendar: calendar))
        return holidays
    }

    private static func substituteHolidays(for holidays: Set<Date>, calendar: Calendar) -> Set<Date> {
        var results = Set<Date>()
        for holiday in holidays where calendar.component(.weekday, from: holiday) == 1 {
            var substitute = calendar.date(byAdding: .day, value: 1, to: holiday) ?? holiday
            while holidays.contains(calendar.startOfDay(for: substitute)) || results.contains(calendar.startOfDay(for: substitute)) {
                substitute = calendar.date(byAdding: .day, value: 1, to: substitute) ?? substitute
            }
            results.insert(calendar.startOfDay(for: substitute))
        }
        return results
    }

    private static func citizensHolidays(for holidays: Set<Date>, year: Int, calendar: Calendar) -> Set<Date> {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 2)),
              let end = calendar.date(from: DateComponents(year: year, month: 12, day: 30))
        else { return [] }

        var results = Set<Date>()
        var day = calendar.startOfDay(for: start)
        let finalDay = calendar.startOfDay(for: end)
        while day <= finalDay {
            let previous = calendar.date(byAdding: .day, value: -1, to: day).map { calendar.startOfDay(for: $0) }
            let next = calendar.date(byAdding: .day, value: 1, to: day).map { calendar.startOfDay(for: $0) }
            if calendar.component(.weekday, from: day) != 1,
               !holidays.contains(day),
               previous.map({ holidays.contains($0) }) == true,
               next.map({ holidays.contains($0) }) == true {
                results.insert(day)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day).map { calendar.startOfDay(for: $0) } ?? finalDay
        }
        return results
    }

    private static func nthWeekday(year: Int, month: Int, weekday: Int, ordinal: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = ordinal
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private static func vernalEquinoxDay(_ year: Int) -> Int {
        Int(floor(20.8431 + 0.242194 * Double(year - 1980) - floor(Double(year - 1980) / 4.0)))
    }

    private static func autumnalEquinoxDay(_ year: Int) -> Int {
        Int(floor(23.2488 + 0.242194 * Double(year - 1980) - floor(Double(year - 1980) / 4.0)))
    }
}
