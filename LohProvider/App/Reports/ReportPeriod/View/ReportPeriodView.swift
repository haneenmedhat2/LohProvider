import SwiftUI

struct MerchantReportPeriodView: View {
    @EnvironmentObject private var store: MerchantReportsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var draft: MerchantReportPeriod
    @State private var preset: MerchantReportPreset?
    @State private var error = false
    @State private var choosingEnd = false
    @State private var activeDateField: String?
    @State private var calendarMonth: Date
    init(period: MerchantReportPeriod, filter: MerchantReportFilter) {
        _draft = State(initialValue: period)
        _calendarMonth = State(initialValue: period.end)
        let preset: MerchantReportPreset?
        switch filter { case .week: preset = .week; case .month: preset = .month; case .quarter: preset = .quarter; case .year: preset = .year; case .custom: preset = nil }
        _preset = State(initialValue: preset)
    }
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Text(text("report_select_period")).merchantFont(18, .medium)
                        .foregroundStyle(MerchantTheme.heading)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 72)
                    HStack {
                        Button(text("report_reset")) {
                            draft = MerchantReportPreset.week.period(ending: store.latestDate)
                            calendarMonth = draft.end
                            preset = .week; error = false; choosingEnd = false
                        }
                            .merchantFont(13, .bold).foregroundStyle(MerchantTheme.success)
                        Spacer()
                        Button { dismiss() } label: {
                            MerchantReportIcon(name: "Close", size: 20, localized: false).frame(width: 44, height: 44)
                        }.accessibilityLabel(text("nav_close"))
                    }
                }
                Text(text("report_period_hint")).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ForEach(MerchantReportPreset.allCases.reversed()) { preset in
                        let selected = self.preset == preset
                        Button {
                            draft = preset.period(ending: store.latestDate)
                            calendarMonth = draft.end
                            self.preset = preset
                            error = false; choosingEnd = false
                        } label: {
                            VStack(spacing: 8) {
                                MerchantReportIcon(name: "PresetCalendar", size: 36, localized: false,
                                                   tint: selected ? MerchantTheme.brand : MerchantTheme.muted)
                                    .overlay(alignment: .bottom) {
                                        if let days = preset.days { Text(String(days)).font(.system(size: 9, weight: .bold)).foregroundStyle(selected ? MerchantTheme.brand : MerchantTheme.muted).padding(.bottom, 4) }
                                    }
                                Text(text(preset.key)).merchantFont(10, .semibold).multilineTextAlignment(.center)
                            }.frame(maxWidth: .infinity, minHeight: 76).padding(.vertical, 4)
                                .foregroundStyle(selected ? MerchantTheme.brand : MerchantTheme.body)
                                .background(selected ? MerchantTheme.brandTint : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? MerchantTheme.brand : MerchantTheme.border))
                        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                HStack(alignment: .bottom, spacing: 8) {
                    dateField("report_from", value: $draft.start)
                    Image(systemName: "arrow.forward").font(.system(size: 12))
                        .foregroundStyle(MerchantTheme.muted).frame(height: 42)
                        .accessibilityHidden(true)
                    dateField("report_to", value: $draft.end)
                }
                HStack(spacing: 16) {
                    Text(text("report_selected") + " " + MerchantReportFormat.period(draft, arabic: arabic))
                        .merchantFont(12).foregroundStyle(MerchantTheme.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    MerchantReportIcon(name: "Calendar", size: 24, tint: MerchantTheme.brand)
                        .frame(width: 48, height: 48)
                        .background(MerchantTheme.brandTint, in: Circle())
                }
                calendarHeader
                HStack {
                    ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label).merchantFont(10).foregroundStyle(MerchantTheme.muted).frame(maxWidth: .infinity)
                    }
                }.environment(\.layoutDirection, .leftToRight)
                calendarGrid
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if error || !draft.isValid {
                    MerchantFieldError(message: text("report_range_error"))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("reportPeriodRangeWarning")
                }
                MerchantButton(title: text("report_apply")) {
                    guard store.apply(draft, preset: preset) else { error = true; return }
                    dismiss()
                }.accessibilityIdentifier("reportPeriodApply")
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
            .background(.white)
        }
        .background(.white).presentationBackground(.white)
            .environment(\.calendar, MerchantReportsViewModel.calendar)
            .environment(\.timeZone, MerchantReportsViewModel.calendar.timeZone)
    }
    private func dateField(_ key: String, value: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text(key)).merchantFont(12).foregroundStyle(MerchantTheme.secondary)
            Button { activeDateField = key } label: {
                HStack(spacing: 6) {
                    Text(MerchantReportFormat.date(value.wrappedValue, arabic: arabic))
                        .merchantFont(12).foregroundStyle(MerchantTheme.heading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MerchantReportIcon(name: "Calendar", size: 16,
                                       tint: activeDateField == key ? MerchantTheme.brand : MerchantTheme.muted)
                }
                .padding(.horizontal, 10).frame(minHeight: 42)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(MerchantTheme.border))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text(key))
            .accessibilityValue(MerchantReportFormat.date(value.wrappedValue, arabic: arabic))
            .popover(isPresented: Binding(
                get: { activeDateField == key },
                set: { if !$0 { activeDateField = nil } }
            )) {
                DatePicker(text(key), selection: value,
                           in: store.earliestDate...store.latestDate,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical).tint(MerchantTheme.brand)
                    .padding(12).frame(width: 320)
                    .environment(\.locale, locale)
                    .environment(\.calendar, MerchantReportsViewModel.calendar)
                    .environment(\.timeZone, MerchantReportsViewModel.calendar.timeZone)
                    .presentationCompactAdaptation(.popover)
                    .onChange(of: value.wrappedValue) { _ in
                        calendarMonth = value.wrappedValue
                        activeDateField = nil
                        preset = nil
                        choosingEnd = false
                        error = false
                    }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
    }
    private var weekdayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        return formatter.veryShortWeekdaySymbols
    }
    private var monthStart: Date {
        let calendar = MerchantReportsViewModel.calendar
        return calendar.date(from: calendar.dateComponents([.year, .month], from: calendarMonth))!
    }

    private func shiftedMonth(_ months: Int) -> Date {
        MerchantReportsViewModel.calendar.date(byAdding: .month, value: months, to: monthStart)!
    }

    private var calendarHeader: some View {
        let calendar = MerchantReportsViewModel.calendar
        let earliestMonth = store.earliestDate == .distantPast ? nil :
            calendar.date(from: calendar.dateComponents([.year, .month], from: store.earliestDate))
        let latestMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: store.latestDate))!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        formatter.dateFormat = "MMMM yyyy"
        return HStack {
            Button { calendarMonth = shiftedMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 40, height: 40)
            }
            .disabled(earliestMonth.map { shiftedMonth(-1) < $0 } ?? false)
            .accessibilityLabel(text("report_previous_month"))
            Spacer()
            Text(formatter.string(from: monthStart))
                .merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
            Spacer()
            Button { calendarMonth = shiftedMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 40, height: 40)
            }
            .disabled(shiftedMonth(1) > latestMonth)
            .accessibilityLabel(text("report_next_month"))
        }
        .foregroundStyle(MerchantTheme.brand)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var calendarGrid: some View {
        let calendar = MerchantReportsViewModel.calendar
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
        let cellCount = ((leadingDays + daysInMonth + 6) / 7) * 7
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(0..<cellCount, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset - leadingDays, to: monthStart)!
                let inMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
                let endpoint = calendar.isDate(date, inSameDayAs: draft.start) || calendar.isDate(date, inSameDayAs: draft.end)
                let included = draft.isValid &&
                    calendar.compare(date, to: draft.start, toGranularity: .day) != .orderedAscending &&
                    calendar.compare(date, to: draft.end, toGranularity: .day) != .orderedDescending
                Button {
                    preset = nil
                    if !choosingEnd { draft.start = date; draft.end = date; choosingEnd = true }
                    else { draft = .init(start: min(draft.start, date), end: max(draft.start, date)); choosingEnd = false }
                    if !inMonth { calendarMonth = date }
                    error = false
                } label: {
                    Text(String(calendar.component(.day, from: date)))
                        .merchantFont(12, endpoint ? .bold : .regular)
                        .foregroundStyle(endpoint ? .white : inMonth ? MerchantTheme.body : MerchantTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if included { RoundedRectangle(cornerRadius: 9).fill(MerchantTheme.success.opacity(0.12)) }
                            if endpoint { Circle().fill(MerchantTheme.success) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(date < store.earliestDate || date > store.latestDate)
                .accessibilityLabel(MerchantReportFormat.date(date, arabic: arabic))
                .accessibilityAddTraits(included ? [.isSelected] : [])
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
