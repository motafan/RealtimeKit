import SwiftUI
import RealtimeCore
import RealtimeSwiftUI

@main
struct RealtimeKitSwiftUIDemoApp: App {
    @StateObject private var realtimeManager = RealtimeManager.shared
    
    init() {
        // 配置 RealtimeKit
        Task {
            do {
                let config = RealtimeConfig(
                    appId: "demo_app_id",
                    appCertificate: "demo_app_certificate",
                    provider: .mock // 使用 Mock 服务商进行演示
                )
                try await RealtimeManager.shared.configure(provider: .mock, config: config)
                print("RealtimeKit SwiftUI Demo configured successfully")
            } catch {
                print("Failed to configure RealtimeKit: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(realtimeManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainDemoView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("主页")
                }
                .tag(0)
            
            UserLoginView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("用户登录")
                }
                .tag(1)
            
            RoomManagementView()
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("房间管理")
                }
                .tag(2)
            
            AudioControlView()
                .tabItem {
                    Image(systemName: "speaker.wave.3.fill")
                    Text("音频控制")
                }
                .tag(3)
            
            VolumeVisualizationView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("音量可视化")
                }
                .tag(4)
            
            StreamPushView()
                .tabItem {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("转推流")
                }
                .tag(5)
            
            MediaRelayView()
                .tabItem {
                    Image(systemName: "arrow.triangle.branch")
                    Text("媒体中继")
                }
                .tag(6)
        }
        .accentColor(.blue)
    }
}

struct MainDemoView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题和状态
                    VStack(spacing: 16) {
                        Text("RealtimeKit SwiftUI Demo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        StatusCardView()
                    }
                    .padding(.top)
                    
                    // 功能卡片网格
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        FeatureCard(
                            title: "用户登录",
                            icon: "person.circle.fill",
                            color: .blue,
                            description: "管理用户身份和角色"
                        )
                        
                        FeatureCard(
                            title: "房间管理",
                            icon: "video.fill",
                            color: .green,
                            description: "创建和加入实时通信房间"
                        )
                        
                        FeatureCard(
                            title: "音频控制",
                            icon: "speaker.wave.3.fill",
                            color: .orange,
                            description: "控制麦克风和音量设置"
                        )
                        
                        FeatureCard(
                            title: "音量可视化",
                            icon: "waveform",
                            color: .purple,
                            description: "实时显示说话状态和音量"
                        )
                        
                        FeatureCard(
                            title: "转推流",
                            icon: "dot.radiowaves.left.and.right",
                            color: .red,
                            description: "推流到第三方平台"
                        )
                        
                        FeatureCard(
                            title: "媒体中继",
                            icon: "arrow.triangle.branch",
                            color: .teal,
                            description: "跨频道媒体流转发"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct StatusCardView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    
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
            
            if let session = realtimeManager.currentSession {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("用户:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.userName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("角色:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(session.userRole.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    if let roomId = session.roomId {
                        HStack {
                            Text("房间:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(roomId)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private var statusColor: Color {
        if realtimeManager.currentSession != nil {
            return .green
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if realtimeManager.currentSession != nil {
            return "已登录"
        } else {
            return "未登录"
        }
    }
}

struct FeatureCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(RealtimeManager.shared)
}