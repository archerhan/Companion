//
//  SettingsView.swift
//  Companion
//
//  Created by it on 2025/12/17.
//

import SwiftUI

struct SettingsView: View {
    // 直接绑定 UserDefaults，Key 需要和 AppConfig 里的保持一致
    @AppStorage("cfg_enableSound") private var enableSound: Bool = true
    @AppStorage("cfg_waterInterval") private var waterInterval: Double = 2700
    @AppStorage("cfg_pomodoroDuration") private var pomodoroDuration: Double = 25.0
    @AppStorage("cfg_enableWaterReminder") private var enableWaterReminder: Bool = true
    @AppStorage("cfg_enableHourlyChime") private var enableHourlyChime: Bool = true
    
    var body: some View {
        Form {
            Section(header: Text("settings_title").font(.title)) {
                Toggle("settings_enable_sound", isOn: $enableSound)
                    .toggleStyle(SwitchToggleStyle())
            }
            Divider().padding(.vertical, 10)
            Section(header: Text("settings_reminder_title").font(.title)) {
                // 1. 喝水提醒开关
                Toggle("settings_enable_water", isOn: $enableWaterReminder)
                    .toggleStyle(SwitchToggleStyle())
                
                // 间隔选择 (如果开关关闭，则禁用此项，视觉上变灰)
                Picker("settings_water_interval", selection: $waterInterval) {
                    Text("time_min_15").tag(900.0)
                    Text("time_min_30").tag(1800.0)
                    Text("time_min_45").tag(2700.0)
                    Text("time_min_60").tag(3600.0)
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(!enableWaterReminder) // 【优化】
                
                // 2. 整点报时开关
                Toggle("settings_enable_chime", isOn: $enableHourlyChime)
                    .toggleStyle(SwitchToggleStyle())
            }
            Divider().padding(.vertical, 10)
            Section(header: Text("settings_focus_title").font(.title)) {
                Picker("settings_pomodoro_duration", selection: $pomodoroDuration) {
                    Text("time_min_15").tag(15.0)
                    Text("time_min_25").tag(25.0)
                    Text("time_min_30").tag(30.0)
                    Text("time_min_45").tag(45.0)
                    Text("time_min_60").tag(60.0)
                }
                .pickerStyle(MenuPickerStyle())
            }
            Spacer()
            Text("settings_footer")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 350, height: 400)
    }
}
