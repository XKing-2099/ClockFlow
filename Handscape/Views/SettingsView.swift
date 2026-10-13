import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: ClockSettings
    let onDemonstrate: () -> Void
    let onPreviewOccasion: (ChoreographyOccasion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        ForEach(HandPalette.allCases) { palette in
                            Button {
                                settings.preferences.palette = palette
                            } label: {
                                VStack(spacing: 9) {
                                    ZStack {
                                        Circle().fill(palette.faceFill)
                                        Circle().stroke(palette.faceOutline, lineWidth: 0.8)
                                        Path { path in
                                            path.move(to: CGPoint(x: 16, y: 6))
                                            path.addLine(to: CGPoint(x: 16, y: 16))
                                            path.addLine(to: CGPoint(x: 25, y: 16))
                                        }
                                        .stroke(palette.color, style: StrokeStyle(lineWidth: 32 * ClockHandGeometry.strokeRatio, lineCap: .round, lineJoin: .round))
                                    }
                                    .frame(width: 32, height: 32)
                                    Text(palette.title).font(.system(size: 12))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.white.opacity(settings.preferences.palette == palette ? 0.1 : 0.025))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.white.opacity(settings.preferences.palette == palette ? 0.3 : 0), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.8))
                            .accessibilityLabel("\(palette.title)指针")
                            .accessibilityAddTraits(settings.preferences.palette == palette ? .isSelected : [])
                        }
                    }
                    .listRowBackground(Color.clear)
                    Toggle("显示表盘", isOn: $settings.preferences.showFaces)
                        .tint(.green)
                    Toggle("24 小时制", isOn: $settings.preferences.uses24HourTime)
                        .tint(.green)
                    Toggle("显示日期", isOn: $settings.preferences.showDate)
                        .tint(.green)
                    Toggle("轻微位移", isOn: $settings.preferences.subtleDrift)
                        .tint(.green)
                } header: {
                    Text("画面")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("石墨配色使用清晰的炭灰表盘与加粗柔白指针，背景始终为纯黑。沉浸时将整组时钟等比例放大到安全区允许的最大尺寸，靠近摄像头一侧只留少量缓冲，不改变钟面间距比例。横屏四位并列，竖屏上下排列小时和分钟；日期独立排在时钟下方。")
                        Text("轻微位移开启时，整组时钟每分钟在横向 ±3 点、纵向 ±2 点范围内微调位置，避免内容始终固定在同一位置。关闭后钟面位置固定，不影响指针编舞；微移不能保证完全避免残影。")
                    }
                }

                Section {
                    ForEach(MotionStyle.allCases) { motion in
                        Button {
                            settings.preferences.motion = motion
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: motion.symbol)
                                    .font(.system(size: 20))
                                    .frame(width: 28)
                                    .foregroundStyle(settings.preferences.palette.color.opacity(0.85))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(motion.title).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text(motion.subtitle).font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                if settings.preferences.motion == motion {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(settings.preferences.palette.color)
                                }
                            }
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("motion-\(motion.rawValue)")
                        .accessibilityAddTraits(settings.preferences.motion == motion ? .isSelected : [])
                    }

                    VStack(spacing: 10) {
                        HStack {
                            Text("基础动画时长")
                            Spacer()
                            Text("\(Int(settings.preferences.animationDuration)) 秒")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.preferences.animationDuration, in: 3...12, step: 1)
                            .accessibilityLabel("动画时长")
                    }
                    Toggle("减少动画", isOn: $settings.preferences.reduceMotion)
                        .tint(.green)
                    Button(action: onDemonstrate) {
                        Label("立即演示", systemImage: "play.circle")
                    }
                } header: {
                    Text("分钟切换")
                } footer: {
                    Text("自动轮换依次播放八种编舞；随机每次抽选一种且不连续重复，也可固定选择一种。每到整分钟，指针先编舞，再组成当前时间。随机不会改变整点或十分钟彩蛋的规则。系统的“减弱动态效果”设置也会关闭编舞和彩蛋。")
                }

                Section {
                    Toggle("整点与十分钟彩蛋", isOn: $settings.preferences.milestoneChoreography)
                        .tint(.green)
                        .accessibilityIdentifier("milestone-choreography")
                    Button {
                        onPreviewOccasion(.tenMinute)
                    } label: {
                        Label("预览十分钟彩蛋", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier("preview-ten-minute")
                    Button {
                        onPreviewOccasion(.hour)
                    } label: {
                        Label("预览整点彩蛋", systemImage: "sun.max")
                    }
                    .accessibilityIdentifier("preview-hour")
                } header: {
                    Text("时间彩蛋")
                } footer: {
                    Text("每逢 10、20、30、40、50 分，轮换展示菱形、风车、丝带、星芒或花瓣，图案停留 1.5 秒。整点优先播放礼花绽放，停留 2 秒。停留时长额外计入，不会挤占基础动画。预览不需要等待真实时间。")
                }

                Section {
                    Toggle("保持屏幕开启", isOn: $settings.preferences.keepScreenAwake)
                        .tint(.green)
                    Toggle("沉浸时降低亮度", isOn: $settings.preferences.dimDisplay)
                        .tint(.green)
                    VStack(spacing: 10) {
                        HStack {
                            Text("沉浸亮度")
                            Spacer()
                            Text("\(Int((settings.preferences.brightness * 100).rounded()))%")
                                .monospacedDigit().foregroundStyle(.secondary)
                                .accessibilityIdentifier("immersive-brightness-value")
                        }
                        Slider(value: $settings.preferences.brightness, in: ClockPreferences.brightnessRange, step: 0.01)
                            .accessibilityLabel("沉浸模式屏幕亮度")
                            .accessibilityIdentifier("immersive-brightness-slider")
                    }
                    .disabled(!settings.preferences.dimDisplay)
                } header: {
                    Text("充电支架")
                } footer: {
                    Text("控制界面会在 8 秒后隐去，时钟随之放大并应用沉浸亮度，默认 30%，可在 4–80% 之间调节。轻点钟面恢复控制和可读亮度；切到后台或锁屏会恢复原亮度。此模式需要应用保持在前台，适合连接充电器使用；提高亮度会增加功耗，建议按摆放环境调节。")
                }

                Section {
                    HStack {
                        Text("ClockFlow")
                        Spacer()
                        Text("0.2 · 个人体验版").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Text("由 24 个钟面和 48 根指针组成的动态时钟。视觉概念参考 Humans since 1982 的 ClockClock 24；本应用使用自行编写的绘制与编舞代码，与原工作室无关联。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Link("了解原作 · Humans since 1982", destination: URL(string: "https://www.humanssince1982.com/collections/collectibles")!)
                        .font(.system(size: 13))
                } header: {
                    Text("关于")
                }
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("clock-settings-list")
            .background(Color(white: 0.025))
            .tint(settings.preferences.palette.color)
            .navigationTitle("时钟设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

