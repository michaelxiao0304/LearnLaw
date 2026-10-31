import SwiftUI

struct ReminderSettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(ReminderService.self) private var service
    @Environment(\.openURL) private var openURL
    private var selectedTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: preferences.reminderHour, minute: preferences.reminderMinute)) ?? .now
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            preferences.reminderHour = parts.hour ?? 9; preferences.reminderMinute = parts.minute ?? 0
        })
    }
    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("每日提醒", isOn: $preferences.reminderEnabled)
                DatePicker("提醒时间", selection: selectedTime, displayedComponents: .hourAndMinute)
                    .disabled(!preferences.reminderEnabled)
                Text("提醒由本机系统调度，无需联网；静音、专注模式和通知设置可能影响显示与声音。").font(.footnote)
            }
            if service.authorization == .denied {
                Section {
                    Text("系统通知权限已关闭，今日一题仍可正常使用。")
                    Button("打开系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            if let error = service.error {
                Section { Text(error); Button("重试") { update(requestPermission: true) } }
            }
        }.navigationTitle("每日提醒")
            .task { await service.synchronize(preferences.reminderSettings) }
            .onChange(of: preferences.reminderEnabled) { _, enabled in update(requestPermission: enabled) }
            .onChange(of: preferences.reminderHour) { _, _ in update() }
            .onChange(of: preferences.reminderMinute) { _, _ in update() }
    }
    private func update(requestPermission: Bool = false) {
        Task { await service.synchronize(preferences.reminderSettings, requestPermission: requestPermission) }
    }
}
