import SwiftUI
import RealtimeCore

struct AudioControlView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("音频控制")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("管理麦克风和音量设置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 音频开关
                    VStack(spacing: 16) {
                        SectionHeader(title: "音频开关")
                        
                        VStack(spacing: 16) {
                            AudioToggleRow(
                                title: "麦克风",
                                icon: "mic.fill",
                                isOn: !realtimeManager.audioSettings.microphoneMuted,
                                color: .blue
                            ) { isOn in
                                toggleMicrophone(!isOn)
                            }
                            
                            AudioToggleRow(
                                title: "本地音频流",
                                icon: "waveform",
                                isOn: realtimeManager.audioSettings.localAudioStreamActive,
                                color: .green
                            ) { isOn in
                                toggleAudioStream(isOn)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 音量控制
                    VStack(spacing: 16) {
                        SectionHeader(title: "音量控制")
                        
                        VStack(spacing: 20) {
                            VolumeSliderRow(
                                title: "混音音量",
                                icon: "speaker.2.fill",
                                value: Double(realtimeManager.audioSettings.audioMixingVolume),
                                color: .purple
                            ) { value in
                                setAudioMixingVolume(Int(value))
                            }
                            
                            VolumeSliderRow(
                                title: "播放音量",
                                icon: "speaker.3.fill",
                                value: Double(realtimeManager.audioSettings.playbackSignalVolume),
                                color: .blue
                            ) { value in
                                setPlaybackVolume(Int(value))
                            }
                            
                            VolumeSliderRow(
                                title: "录制音量",
                                icon: "mic.circle.fill",
                                value: Double(realtimeManager.audioSettings.recordingSignalVolume),
                                color: .red
                            ) { value in
                                setRecordingVolume(Int(value))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 快速设置
                    VStack(spacing: 16) {
                        SectionHeader(title: "快速设置")
                        
                        HStack(spacing: 12) {
                            Button(action: muteAll) {
                                HStack {
                                    Image(systemName: "speaker.slash.fill")
                                    Text("全部静音")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            
                            Button(action: resetSettings) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("重置设置")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    // 当前设置
                    VStack(spacing: 16) {
                        SectionHeader(title: "当前设置")
                        
                        AudioSettingsCard(settings: realtimeManager.audioSettings)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("音频控制")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func toggleMicrophone(_ muted: Bool) {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.muteMicrophone(muted)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "操作失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func toggleAudioStream(_ active: Bool) {
        isLoading = true
        
        Task {
            do {
                if active {
                    try await realtimeManager.resumeLocalAudioStream()
                } else {
                    try await realtimeManager.stopLocalAudioStream()
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "操作失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setAudioMixingVolume(_ volume: Int) {
        Task {
            do {
                try await realtimeManager.setAudioMixingVolume(volume)
            } catch {
                await MainActor.run {
                    showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setPlaybackVolume(_ volume: Int) {
        Task {
            do {
                try await realtimeManager.setPlaybackSignalVolume(volume)
            } catch {
                await MainActor.run {
                    showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setRecordingVolume(_ volume: Int) {
        Task {
            do {
                try await realtimeManager.setRecordingSignalVolume(volume)
            } catch {
                await MainActor.run {
                    showAlert(title: "设置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func muteAll() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.muteMicrophone(true)
                try await realtimeManager.setAudioMixingVolume(0)
                try await realtimeManager.setPlaybackSignalVolume(0)
                try await realtimeManager.setRecordingSignalVolume(0)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "已全部静音")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "操作失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func resetSettings() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.resetAudioSettings()
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "设置已重置为默认值")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "重置失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct AudioToggleRow: View {
    let title: String
    let icon: String
    let isOn: Bool
    let color: Color
    let action: (Bool) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { action($0) }
            ))
            .labelsHidden()
        }
    }
}

struct VolumeSliderRow: View {
    let title: String
    let icon: String
    let value: Double
    let color: Color
    let action: (Double) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(value))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(width: 30)
            }
            
            Slider(
                value: Binding(
                    get: { value },
                    set: { action($0) }
                ),
                in: 0...100,
                step: 1
            ) {
                Text(title)
            }
            .accentColor(color)
        }
    }
}

struct AudioSettingsCard: View {
    let settings: AudioSettings
    
    var body: some View {
        VStack(spacing: 12) {
            InfoRow(label: "麦克风", value: settings.microphoneMuted ? "静音" : "开启")
            InfoRow(label: "本地音频流", value: settings.localAudioStreamActive ? "活跃" : "停止")
            InfoRow(label: "混音音量", value: "\(settings.audioMixingVolume)%")
            InfoRow(label: "播放音量", value: "\(settings.playbackSignalVolume)%")
            InfoRow(label: "录制音量", value: "\(settings.recordingSignalVolume)%")
            InfoRow(label: "最后修改", value: formatDate(settings.lastModified))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    AudioControlView()
        .environmentObject(RealtimeManager.shared)
}