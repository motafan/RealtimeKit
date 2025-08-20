import SwiftUI
import RealtimeCore

struct StreamPushView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var pushUrl = "rtmp://demo.server.com/live/stream_\(Int.random(in: 1000...9999))"
    @State private var selectedResolution = 0 // 0: 720p, 1: 1080p, 2: 4K
    @State private var bitrate: Double = 2000
    @State private var framerate: Double = 30
    @State private var selectedLayout = StreamLayout.single
    @State private var backgroundColor = Color.black
    @State private var showingColorPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isLoading = false
    
    private let resolutions = ["720p", "1080p", "4K"]
    private let layouts: [StreamLayout] = [.single, .dual, .quad, .custom([])]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("转推流")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("推流到第三方平台")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 推流配置
                    VStack(spacing: 16) {
                        SectionHeader(title: "推流配置")
                        
                        VStack(spacing: 16) {
                            CustomTextField(
                                title: "推流URL",
                                text: $pushUrl,
                                placeholder: "输入推流URL (rtmp://...)"
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("分辨率")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Picker("分辨率", selection: $selectedResolution) {
                                    ForEach(0..<resolutions.count, id: \.self) { index in
                                        Text(resolutions[index]).tag(index)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            ConfigSliderRow(
                                title: "码率 (kbps)",
                                value: $bitrate,
                                range: 500...8000,
                                step: 100,
                                color: .blue,
                                formatter: { "\(Int($0))" }
                            ) { _ in }
                            
                            ConfigSliderRow(
                                title: "帧率 (fps)",
                                value: $framerate,
                                range: 15...60,
                                step: 5,
                                color: .green,
                                formatter: { "\(Int($0))" }
                            ) { _ in }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 布局配置
                    VStack(spacing: 16) {
                        SectionHeader(title: "布局配置")
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("布局模式")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(layouts, id: \.self) { layout in
                                        LayoutSelectionCard(
                                            layout: layout,
                                            isSelected: selectedLayout == layout
                                        ) {
                                            selectedLayout = layout
                                        }
                                    }
                                }
                            }
                            
                            Button(action: { showingColorPicker = true }) {
                                HStack {
                                    Text("背景颜色")
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(backgroundColor)
                                        .frame(width: 40, height: 24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray, lineWidth: 1)
                                        )
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 推流预览
                    VStack(spacing: 16) {
                        SectionHeader(title: "推流预览")
                        
                        StreamPreviewCard(
                            layout: selectedLayout,
                            backgroundColor: backgroundColor
                        )
                    }
                    
                    // 推流控制
                    VStack(spacing: 16) {
                        SectionHeader(title: "推流控制")
                        
                        VStack(spacing: 12) {
                            if realtimeManager.streamPushState != .running {
                                Button(action: startStreamPush) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                        }
                                        Text("开始推流")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading || pushUrl.isEmpty)
                            } else {
                                HStack(spacing: 12) {
                                    Button(action: stopStreamPush) {
                                        HStack {
                                            if isLoading {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "stop.circle.fill")
                                            }
                                            Text("停止推流")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .disabled(isLoading)
                                    
                                    Button(action: updateLayout) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("更新布局")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .disabled(isLoading)
                                }
                            }
                        }
                    }
                    
                    // 推流状态
                    VStack(spacing: 16) {
                        SectionHeader(title: "推流状态")
                        
                        StreamPushStatusCard(
                            state: realtimeManager.streamPushState,
                            config: currentConfig
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("转推流")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $backgroundColor)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var currentConfig: StreamPushConfig {
        let resolution = getResolution(for: selectedResolution)
        return StreamPushConfig(
            pushUrl: pushUrl,
            width: resolution.width,
            height: resolution.height,
            bitrate: Int(bitrate),
            framerate: Int(framerate),
            layout: selectedLayout,
            backgroundColor: UIColor(backgroundColor)
        )
    }
    
    private func getResolution(for index: Int) -> (width: Int, height: Int) {
        switch index {
        case 0: return (1280, 720)   // 720p
        case 1: return (1920, 1080)  // 1080p
        case 2: return (3840, 2160)  // 4K
        default: return (1280, 720)
        }
    }
    
    private func startStreamPush() {
        guard !pushUrl.isEmpty else {
            showAlert(title: "错误", message: "请输入推流URL")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.startStreamPush(config: currentConfig)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "推流启动成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "启动失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func stopStreamPush() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.stopStreamPush()
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "推流停止成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "停止失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateLayout() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.updateStreamPushLayout(layout: selectedLayout)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "布局更新成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "更新失败", message: error.localizedDescription)
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

struct LayoutSelectionCard: View {
    let layout: StreamLayout
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: layoutIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(layout.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var layoutIcon: String {
        switch layout {
        case .single: return "rectangle.fill"
        case .dual: return "rectangle.split.2x1.fill"
        case .quad: return "rectangle.split.2x2.fill"
        case .custom: return "rectangle.grid.1x2.fill"
        }
    }
}

struct StreamPreviewCard: View {
    let layout: StreamLayout
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .frame(height: 200)
                
                layoutPreview
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, lineWidth: 1)
            )
            
            Text("预览: \(layout.displayName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    @ViewBuilder
    private var layoutPreview: some View {
        switch layout {
        case .single:
            singleLayoutPreview
        case .dual:
            dualLayoutPreview
        case .quad:
            quadLayoutPreview
        case .custom:
            customLayoutPreview
        }
    }
    
    private var singleLayoutPreview: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue.opacity(0.3))
            .overlay(
                Text("主播")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            )
            .frame(width: 160, height: 120)
    }
    
    private var dualLayoutPreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    Text("用户1")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                )
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.green.opacity(0.3))
                .overlay(
                    Text("用户2")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                )
        }
        .frame(width: 160, height: 80)
    }
    
    private var quadLayoutPreview: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        Text("用户1")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    )
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.3))
                    .overlay(
                        Text("用户2")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    )
            }
            
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.3))
                    .overlay(
                        Text("用户3")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    )
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.purple.opacity(0.3))
                    .overlay(
                        Text("用户4")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    )
            }
        }
        .frame(width: 160, height: 120)
    }
    
    private var customLayoutPreview: some View {
        Text("自定义布局")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
    }
}

struct StreamPushStatusCard: View {
    let state: StreamPushState
    let config: StreamPushConfig
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(state.displayName)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                Spacer()
            }
            
            if state == .running {
                VStack(spacing: 8) {
                    InfoRow(label: "推流URL", value: config.pushUrl)
                    InfoRow(label: "分辨率", value: "\(config.width)x\(config.height)")
                    InfoRow(label: "码率", value: "\(config.bitrate) kbps")
                    InfoRow(label: "帧率", value: "\(config.framerate) fps")
                    InfoRow(label: "布局", value: config.layout.displayName)
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
        switch state {
        case .stopped: return .gray
        case .starting, .stopping: return .orange
        case .running: return .green
        case .failed: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                ColorPicker("选择背景颜色", selection: $selectedColor)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("背景颜色")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    StreamPushView()
        .environmentObject(RealtimeManager.shared)
}