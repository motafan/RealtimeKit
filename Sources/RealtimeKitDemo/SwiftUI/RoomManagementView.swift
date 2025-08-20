import SwiftUI
import RealtimeCore

struct RoomManagementView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var roomId = "demo_room_\(Int.random(in: 1000...9999))"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isLoading = false
    @State private var participants: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("房间管理")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("创建和管理实时通信房间")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 房间操作
                    VStack(spacing: 16) {
                        SectionHeader(title: "房间操作")
                        
                        VStack(spacing: 12) {
                            CustomTextField(
                                title: "房间ID",
                                text: $roomId,
                                placeholder: "输入房间ID"
                            )
                            
                            HStack(spacing: 12) {
                                Button(action: createRoom) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                        }
                                        Text("创建房间")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading || !canPerformRoomAction)
                                
                                Button(action: joinRoom) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                        }
                                        Text("加入房间")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading || !canPerformRoomAction)
                            }
                            
                            if isInRoom {
                                Button(action: leaveRoom) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.left.circle.fill")
                                        }
                                        Text("离开房间")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 房间状态
                    VStack(spacing: 16) {
                        SectionHeader(title: "房间状态")
                        
                        RoomStatusCard()
                    }
                    
                    // 房间信息
                    if let session = realtimeManager.currentSession, session.isInRoom {
                        VStack(spacing: 16) {
                            SectionHeader(title: "房间信息")
                            
                            RoomInfoCard(session: session)
                        }
                    }
                    
                    // 参与者列表
                    if isInRoom {
                        VStack(spacing: 16) {
                            SectionHeader(title: "参与者列表")
                            
                            ParticipantsListView(participants: participants)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("房间管理")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            updateParticipants()
        }
        .onChange(of: realtimeManager.currentSession) { _ in
            updateParticipants()
        }
    }
    
    private var canPerformRoomAction: Bool {
        return realtimeManager.currentSession != nil && !roomId.isEmpty
    }
    
    private var isInRoom: Bool {
        return realtimeManager.currentSession?.isInRoom == true
    }
    
    private func createRoom() {
        guard !roomId.isEmpty else {
            showAlert(title: "错误", message: "请输入房间ID")
            return
        }
        
        guard let session = realtimeManager.currentSession else {
            showAlert(title: "错误", message: "请先登录")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                _ = try await realtimeManager.createRoom(roomId: roomId)
                try await realtimeManager.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "房间创建并加入成功")
                    updateParticipants()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "创建房间失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func joinRoom() {
        guard !roomId.isEmpty else {
            showAlert(title: "错误", message: "请输入房间ID")
            return
        }
        
        guard let session = realtimeManager.currentSession else {
            showAlert(title: "错误", message: "请先登录")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.joinRoom(roomId: roomId, userId: session.userId, userRole: session.userRole)
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "加入房间成功")
                    updateParticipants()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "加入房间失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func leaveRoom() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.leaveRoom()
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "离开房间成功")
                    updateParticipants()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "离开房间失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateParticipants() {
        if let session = realtimeManager.currentSession, session.isInRoom {
            // 模拟参与者列表
            participants = ["用户1", "用户2", session.userName]
        } else {
            participants = []
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct RoomStatusCard: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(statusColor)
            
            Spacer()
            
            Text(connectionStateText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statusColor: Color {
        if let session = realtimeManager.currentSession, session.isInRoom {
            return .green
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if let session = realtimeManager.currentSession, session.isInRoom {
            return "已在房间中"
        } else {
            return "未在房间中"
        }
    }
    
    private var connectionStateText: String {
        return realtimeManager.connectionState.displayName
    }
}

struct RoomInfoCard: View {
    let session: UserSession
    
    var body: some View {
        VStack(spacing: 12) {
            InfoRow(label: "房间ID", value: session.roomId ?? "未知")
            InfoRow(label: "用户角色", value: session.userRole.displayName)
            InfoRow(label: "连接状态", value: "已连接")
            InfoRow(label: "加入时间", value: formatDate(session.createdAt))
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

struct ParticipantsListView: View {
    let participants: [String]
    
    var body: some View {
        VStack(spacing: 12) {
            if participants.isEmpty {
                Text("暂无参与者")
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
                    ForEach(participants, id: \.self) { participant in
                        ParticipantRow(name: participant)
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

struct ParticipantRow: View {
    let name: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RoomManagementView()
        .environmentObject(RealtimeManager.shared)
}