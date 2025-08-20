import SwiftUI
import RealtimeCore

struct UserLoginView: View {
    @EnvironmentObject var realtimeManager: RealtimeManager
    @State private var userId = "demo_user_\(Int.random(in: 1000...9999))"
    @State private var userName = "演示用户"
    @State private var selectedRole = UserRole.broadcaster
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
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("用户身份管理")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("管理用户登录状态和角色权限")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // 用户信息输入
                    VStack(spacing: 16) {
                        SectionHeader(title: "用户信息")
                        
                        VStack(spacing: 12) {
                            CustomTextField(
                                title: "用户ID",
                                text: $userId,
                                placeholder: "输入用户ID"
                            )
                            
                            CustomTextField(
                                title: "用户名",
                                text: $userName,
                                placeholder: "输入用户名"
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 角色选择
                    VStack(spacing: 16) {
                        SectionHeader(title: "用户角色")
                        
                        VStack(spacing: 8) {
                            ForEach(UserRole.allCases, id: \.self) { role in
                                RoleSelectionRow(
                                    role: role,
                                    isSelected: selectedRole == role
                                ) {
                                    selectedRole = role
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        if realtimeManager.currentSession == nil {
                            Button(action: loginUser) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                    }
                                    Text("登录")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || userId.isEmpty || userName.isEmpty)
                        } else {
                            Button(action: logoutUser) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "person.badge.minus")
                                    }
                                    Text("登出")
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
                    
                    // 会话信息
                    if let session = realtimeManager.currentSession {
                        SessionInfoCard(session: session)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("用户登录")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loginUser() {
        guard !userId.isEmpty && !userName.isEmpty else {
            showAlert(title: "错误", message: "请输入用户ID和用户名")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.loginUser(
                    userId: userId,
                    userName: userName,
                    userRole: selectedRole
                )
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "登录成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "登录失败", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func logoutUser() {
        isLoading = true
        
        Task {
            do {
                try await realtimeManager.logoutUser()
                
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "成功", message: "登出成功")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "登出失败", message: error.localizedDescription)
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

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct RoleSelectionRow: View {
    let role: UserRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(roleDescription(for: role))
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
    
    private func roleDescription(for role: UserRole) -> String {
        switch role {
        case .broadcaster:
            return "拥有音视频权限，可以管理房间"
        case .audience:
            return "只能观看，无音视频权限"
        case .coHost:
            return "拥有音视频权限，可以连麦"
        case .moderator:
            return "拥有音频权限，可以管理房间"
        }
    }
}

struct SessionInfoCard: View {
    let session: UserSession
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "会话信息")
            
            VStack(spacing: 12) {
                InfoRow(label: "用户ID", value: session.userId)
                InfoRow(label: "用户名", value: session.userName)
                InfoRow(label: "角色", value: session.userRole.displayName)
                InfoRow(label: "房间ID", value: session.roomId ?? "未加入房间")
                InfoRow(label: "登录时间", value: formatDate(session.createdAt))
                InfoRow(label: "会话时长", value: formatDuration(session.duration))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

#Preview {
    UserLoginView()
        .environmentObject(RealtimeManager.shared)
}