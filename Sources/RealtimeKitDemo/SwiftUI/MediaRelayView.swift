import SwiftUI
import RealtimeCore

struct MediaRelayView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var sourceChannelName = "source_channel_\(Int.random(in: 1000...9999))"
    @State private var sourceToken = "source_token_demo"
    @State private var selectedMode = MediaRelayMode.oneToMany
    @State private var targetChannels: [RelayChannelInfo] = []
    @State private var showingAddChannelSheet = false
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
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 60))
                            .foregroundColor(.teal)
                        
                        Text("媒体中继")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("跨频道媒体流转发")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 源频道配置
                    VStack(spacing: 16) {
                        SectionHeader(title: "源频道配置")
                        
                        VStack(spacing: 12) {
                            CustomTextField(
                                title: "频道名称",
                                text: $sourceChannelName,
                                placeholder: "输入源频道名称"
                            )
                            
                            CustomTextField(
                                title: "Token",
                                text: $sourceToken,
                                placeholder: "输入源频道Token"
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 中继模式
                    VStack(spacing: 16) {
                        SectionHeader(title: "中继模式")
                        
                        VStack(spacing: 8) {
                            ForEach(MediaRelayMode.allCases, id: \.self) { mode in
                                RelayModeRow(
                                    mode: mode,
                                    isSelected: selectedMode == mode
                                ) {
                                    selectedMode = mode
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 目标频道管理
                    VStack(spacing: 16) {
                        HStack {
                            SectionHeader(title: "目标频道管理")
                            
                            Spacer()
                            
                            Button(action: { showingAddChannelSheet = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        TargetChannelsListView(
                            channels: targetChannels,
                            onDelete: deleteChannel
                        )
                    }
                    
                    // 中继控制
                    VStack(spacing: 16) {
                        SectionHeader(title: "中继控制")
                        
                        VStack(spacing: 12) {
                            if realtimeManager.mediaRelayState?.overallState != .running {
                                Button(action: startMediaRelay) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                        }
                                        Text("开始中继")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading || targetChannels.isEmpty || sourceChannelName.isEmpty)
                            } else {
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        Button(action: stopMediaRelay) {
                                            HStack {
                                                if isLoading {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                } else {
                                                    Image(systemName: "stop.circle.fill")
                                                }
                                                Text("停止中继")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(isLoading)
                                        
                                        Button(action: pauseResumeRelay) {
                                            HStack {
                                                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                                Text(isPaused ? "恢复中继" : "暂停中继")
                                                    .fontWeight(.semibold)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                        }
                                        .disabled(isLoading)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 中继状态
                    VStack(spacing: 16) {
                        SectionHeader(title: "中继状态")
                        
                        MediaRelayStatusCard(state: realtimeManager.mediaRelayState)
                    }
                    
                    // 统计信息
                    if realtimeManager.mediaRelayState?.overallState == .running {
                        VStack(spacing: 16) {
                            SectionHeader(title: "统计信息")
                            
                            MediaRelayStatsCard()
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("媒体中继")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingAddChannelSheet) {
            AddChannelSheet { channel in
                targetChannels.append(channel)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadSampleData()
        }
    }
    
    private var isPaused: Bool {
        return realtimeManager.mediaRelayState?.overallState == .paused
    }
    
    private func loadSampleData() {
        if targetChannels.isEmpty {
            targetChannels = [
                try! RelayChannelInfo(
                    channelName: "target_channel_1",
                    token: "target_token_1",
                    userId: "demo_user_1",
                    uid: 12345,
                    state: .idle
                ),
                try! RelayChannelInfo(
                    channelName: "target_channel_2",
                    token: "target_token_2",
                    userId: "demo_user_2",
                    uid: 12346,
                    state: .idle
                )
            ]
        }
    }
    
    private func deleteChannel(at offsets: IndexSet) {
        targetChannels.remove(atOffsets: offsets)
    }
    
    private func startMediaRelay() {
        guard !sourceChannelName.isEmpty else {
            showAlert(title: "错误", message: "请输入源频道名称")
            return
        }
        
        guard !targetChannels.isEmpty else {
            showAlert(title: "错误", message: "请至少添加一个目标频道")
            return
        }
        
        isLoading = true
        
        let config = try! MediaRelayConfig(
            sourceChannel: try! RelayChannelInfo(
                channelName: sourceChannelName,
                token: sourceToken,
                userId: "demo_source_user",
                uid: 0,
                state: .idle
            ),
            destinationChannels: targetChannels,
            relayMode: selectedMode
        )
        
        Task {
            do {
                try await realtimeManager.startMediaRelay(config: config)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "媒体中继启动成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "启动失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopMediaRelay() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.stopMediaRelay()
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "媒体中继停止成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "停止失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func pauseResumeRelay() {
        isLoading = true
        
        Task {
            do {
                for channel in targetChannels {
                    if isPaused {
                        try await realtimeManager.resumeMediaRelay(toChannel: channel.channelName)
                    } else {
                        try await realtimeManager.pauseMediaRelay(toChannel: channel.channelName)
                    }
                }
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: isPaused ? "媒体中继恢复成功" : "媒体中继暂停成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: isPaused ? "恢复失败" : "暂停失败", message: error.localizedDescription)
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

struct RelayModeRow: View {
    let mode: MediaRelayMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TargetChannelsListView: View {
    let channels: [RelayChannelInfo]
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if channels.isEmpty {
                Text("暂无目标频道")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(channels.indices, id: \.self) { index in
                        TargetChannelRow(channel: channels[index])
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }
}

struct TargetChannelRow: View {
    let channel: RelayChannelInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.channelName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("UID: \(channel.uid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                
                Text(channel.state.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stateColor: Color {
        switch channel.state {
        case .idle: return .gray
        case .connecting: return .orange
        case .running: return .green
        case .paused: return .yellow
        case .error: return .red
        }
    }
}

struct MediaRelayStatusCard: View {
    let state: MediaRelayState?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Spacer()
            }
            
            if let state = state, state.overallState == .running {
                VStack(spacing: 8) {
                    InfoRow(label: "中继模式", value: "一对多") // 简化显示
                    InfoRow(label: "活跃频道", value: "\(state.activeChannelCount)/\(state.totalChannelCount)")
                    InfoRow(label: "开始时间", value: formatDate(Date()))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statusColor: Color {
        guard let state = state else { return .gray }
        
        switch state.overallState {
        case .idle: return .gray
        case .connecting: return .orange
        case .running: return .green
        case .paused: return .yellow
        case .error: return .red
        }
    }
    
    private var statusText: String {
        guard let state = state else { return "未开始中继" }
        
        switch state.overallState {
        case .idle: return "未开始中继"
        case .connecting: return "正在连接"
        case .running: return "中继运行中"
        case .paused: return "中继已暂停"
        case .error: return "中继错误"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct MediaRelayStatsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            InfoRow(label: "数据传输", value: formatBytes(Int64.random(in: 1000000...10000000)))
            InfoRow(label: "平均码率", value: "\(Int.random(in: 1000...5000)) kbps")
            InfoRow(label: "丢包数", value: "\(Int.random(in: 0...100))")
            InfoRow(label: "延迟", value: "\(Int.random(in: 10...100)) ms")
            InfoRow(label: "运行时长", value: formatDuration(60)) // 模拟1分钟
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct AddChannelSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var channelName = ""
    @State private var token = ""
    @State private var uid = ""
    
    let onAdd: (RelayChannelInfo) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    CustomTextField(
                        title: "频道名称",
                        text: $channelName,
                        placeholder: "输入频道名称"
                    )
                    
                    CustomTextField(
                        title: "Token",
                        text: $token,
                        placeholder: "输入Token"
                    )
                    
                    CustomTextField(
                        title: "用户ID",
                        text: $uid,
                        placeholder: "输入用户ID"
                    )
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("添加目标频道")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("添加") {
                    addChannel()
                }
                .disabled(channelName.isEmpty || uid.isEmpty)
            )
        }
    }
    
    private func addChannel() {
        guard let uidValue = UInt(uid) else { return }
        
        let channel = try! RelayChannelInfo(
            channelName: channelName,
            token: token,
            userId: "demo_user_\(uidValue)",
            uid: uidValue,
            state: .idle
        )
        
        onAdd(channel)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    MediaRelayView()
        .environmentObject(RealtimeManager.shared)
}