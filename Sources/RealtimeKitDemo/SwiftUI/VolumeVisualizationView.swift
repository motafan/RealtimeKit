import SwiftUI
import RealtimeCore

struct VolumeVisualizationView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var isVolumeDetectionEnabled = false
    @State private var detectionInterval: Double = 300
    @State private var speakingThreshold: Double = 0.3
    @State private var smoothFactor: Double = 0.3
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var simulatedUsers = ["用户1", "用户2", "用户3", "当前用户"]
    @State private var simulationTimer: Timer?
    @State private var simulatedVolumeInfos: [UserVolumeInfo] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("音量可视化")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("实时显示说话状态和音量级别")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 音量检测控制
                    VStack(spacing: 16) {
                        SectionHeader(title: "音量检测")
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("启用音量检测")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isVolumeDetectionEnabled)
                                    .labelsHidden()
                                    .onChange(of: isVolumeDetectionEnabled) { enabled in
                                        toggleVolumeDetection(enabled)
                                    }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 检测配置
                    if isVolumeDetectionEnabled {
                        VStack(spacing: 16) {
                            SectionHeader(title: "检测配置")
                            
                            VStack(spacing: 20) {
                                ConfigSliderRow(
                                    title: "检测间隔 (ms)",
                                    value: $detectionInterval,
                                    range: 100...1000,
                                    step: 50,
                                    color: .blue,
                                    formatter: { "\(Int($0))" }
                                ) { _ in
                                    updateVolumeDetectionConfig()
                                }
                                
                                ConfigSliderRow(
                                    title: "说话阈值",
                                    value: $speakingThreshold,
                                    range: 0.1...0.8,
                                    step: 0.1,
                                    color: .green,
                                    formatter: { String(format: "%.1f", $0) }
                                ) { _ in
                                    updateVolumeDetectionConfig()
                                }
                                
                                ConfigSliderRow(
                                    title: "平滑因子",
                                    value: $smoothFactor,
                                    range: 0.1...1.0,
                                    step: 0.1,
                                    color: .orange,
                                    formatter: { String(format: "%.1f", $0) }
                                ) { _ in
                                    updateVolumeDetectionConfig()
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 音量可视化
                    VStack(spacing: 16) {
                        SectionHeader(title: "音量可视化")
                        
                        VolumeVisualizationChart(volumeInfos: currentVolumeInfos)
                    }
                    
                    // 说话状态
                    VStack(spacing: 16) {
                        SectionHeader(title: "说话状态")
                        
                        VStack(spacing: 12) {
                            SpeakingStatusRow(
                                title: "说话用户",
                                value: speakingUsersText,
                                color: .green
                            )
                            
                            SpeakingStatusRow(
                                title: "主讲人",
                                value: dominantSpeakerText,
                                color: .blue
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 统计信息
                    VStack(spacing: 16) {
                        SectionHeader(title: "统计信息")
                        
                        VolumeStatsCard(
                            volumeInfos: currentVolumeInfos,
                            config: currentConfig
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("音量可视化")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            stopSimulation()
        }
    }
    
    private var currentVolumeInfos: [UserVolumeInfo] {
        return isVolumeDetectionEnabled ? simulatedVolumeInfos : []
    }
    
    private var currentConfig: VolumeDetectionConfig {
        return VolumeDetectionConfig(
            detectionInterval: Int(detectionInterval),
            speakingThreshold: Float(speakingThreshold),
            silenceThreshold: 0.05,
            includeLocalUser: true,
            smoothFactor: Float(smoothFactor)
        )
    }
    
    private var speakingUsersText: String {
        let speakingUsers = currentVolumeInfos.filter { $0.isSpeaking }.map { $0.userId }
        return speakingUsers.isEmpty ? "无" : speakingUsers.joined(separator: ", ")
    }
    
    private var dominantSpeakerText: String {
        let dominantSpeaker = currentVolumeInfos
            .filter { $0.isSpeaking }
            .max { $0.volume < $1.volume }?.userId
        return dominantSpeaker ?? "无"
    }
    
    private func toggleVolumeDetection(_ enabled: Bool) {
        if enabled {
            startVolumeDetection()
            startSimulation()
        } else {
            stopVolumeDetection()
            stopSimulation()
        }
    }
    
    private func startVolumeDetection() {
        let config = currentConfig
        
        Task {
            do {
                try await realtimeManager.enableVolumeIndicator(config: config)
            } catch {
                await MainActor.run {
                    isVolumeDetectionEnabled = false
                    showAlert(title: "启用失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopVolumeDetection() {
        Task {
            do {
                try await realtimeManager.disableVolumeIndicator()
            } catch {
                await MainActor.run {
                    showAlert(title: "停用失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateVolumeDetectionConfig() {
        if isVolumeDetectionEnabled {
            startVolumeDetection()
        }
    }
    
    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: detectionInterval / 1000.0, repeats: true) { _ in
            generateSimulatedVolumeData()
        }
    }
    
    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulatedVolumeInfos = []
    }
    
    private func generateSimulatedVolumeData() {
        let volumeInfos = simulatedUsers.map { userId in
            let volume = Float.random(in: 0.0...1.0)
            let isSpeaking = volume > Float(speakingThreshold)
            return UserVolumeInfo(userId: userId, volume: volume, isSpeaking: isSpeaking)
        }
        
        DispatchQueue.main.async {
            self.simulatedVolumeInfos = volumeInfos
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct ConfigSliderRow<T: BinaryFloatingPoint>: View where T.Stride: BinaryFloatingPoint {
    let title: String
    @Binding var value: T
    let range: ClosedRange<T>
    let step: T.Stride
    let color: Color
    let formatter: (T) -> String
    let onChange: (T) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatter(value))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(width: 50)
            }
            
            Slider(
                value: $value,
                in: range,
                step: step
            ) {
                Text(title)
            }
            .accentColor(color)
            .onChange(of: value) { newValue in
                onChange(newValue)
            }
        }
    }
}

struct VolumeVisualizationChart: View {
    let volumeInfos: [UserVolumeInfo]
    
    var body: some View {
        VStack(spacing: 16) {
            if volumeInfos.isEmpty {
                Text("暂无音量数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(volumeInfos, id: \.userId) { volumeInfo in
                        VolumeBarView(volumeInfo: volumeInfo)
                    }
                }
                .frame(height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
}

struct VolumeBarView: View {
    let volumeInfo: UserVolumeInfo
    @State private var animatedHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // 用户名
            Text(volumeInfo.userId)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(volumeInfo.isSpeaking ? .blue : .secondary)
                .lineLimit(1)
                .frame(width: 60)
            
            // 音量条
            VStack {
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(volumeInfo.isSpeaking ? Color.green : Color.blue)
                    .frame(width: 40, height: animatedHeight)
                    .scaleEffect(volumeInfo.isSpeaking ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: volumeInfo.isSpeaking)
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 40)
            )
            
            // 音量值
            Text(String(format: "%.2f", volumeInfo.volume))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onAppear {
            animatedHeight = CGFloat(volumeInfo.volume) * 120
        }
        .onChange(of: volumeInfo.volume) { newVolume in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedHeight = CGFloat(newVolume) * 120
            }
        }
    }
}

struct SpeakingStatusRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct VolumeStatsCard: View {
    let volumeInfos: [UserVolumeInfo]
    let config: VolumeDetectionConfig
    
    var body: some View {
        VStack(spacing: 12) {
            InfoRow(label: "总用户数", value: "\(volumeInfos.count)")
            InfoRow(label: "说话用户数", value: "\(speakingCount)")
            InfoRow(label: "平均音量", value: String(format: "%.2f", averageVolume))
            InfoRow(label: "检测间隔", value: "\(config.detectionInterval)ms")
            InfoRow(label: "说话阈值", value: String(format: "%.1f", config.speakingThreshold))
            InfoRow(label: "平滑因子", value: String(format: "%.1f", config.smoothFactor))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var speakingCount: Int {
        return volumeInfos.filter { $0.isSpeaking }.count
    }
    
    private var averageVolume: Float {
        guard !volumeInfos.isEmpty else { return 0.0 }
        return volumeInfos.map { $0.volume }.reduce(0, +) / Float(volumeInfos.count)
    }
}

#Preview {
    VolumeVisualizationView()
        .environmentObject(RealtimeManager.shared)
}