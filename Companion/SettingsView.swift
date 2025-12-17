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
            Section(header: Text("基础设置").font(.title)) {
                Toggle("开启音效", isOn: $enableSound)
                    .toggleStyle(SwitchToggleStyle())
            }
            Divider().padding(.vertical, 10)
            Section(header: Text("生活提醒").font(.title)) {
                // 1. 喝水提醒开关
                Toggle("开启喝水提醒", isOn: $enableWaterReminder)
                    .toggleStyle(SwitchToggleStyle())
                
                // 间隔选择 (如果开关关闭，则禁用此项，视觉上变灰)
                Picker("喝水提醒间隔", selection: $waterInterval) {
                    Text("15 分钟").tag(900.0)
                    Text("30 分钟").tag(1800.0)
                    Text("45 分钟").tag(2700.0)
                    Text("60 分钟").tag(3600.0)
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(!enableWaterReminder) // 【优化】
                
                // 2. 整点报时开关
                Toggle("开启整点报时", isOn: $enableHourlyChime)
                    .toggleStyle(SwitchToggleStyle())
            }
            Divider().padding(.vertical, 10)
            Section(header: Text("专注模式").font(.title)) {
                Picker("番茄钟时长", selection: $pomodoroDuration) {
                    Text("15 分钟").tag(15.0)
                    Text("25 分钟").tag(25.0)
                    Text("30 分钟").tag(30.0)
                    Text("45 分钟").tag(45.0)
                    Text("60 分钟").tag(60.0)
                }
                .pickerStyle(MenuPickerStyle())
            }
            Spacer()
            Text("设置将即时自动保存")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 350, height: 400)
    }
}
