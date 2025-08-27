import SwiftUI
import RealtimeCore
import RealtimeMocking

/// Main content view for SwiftUI Demo
struct ContentView: View {
    
    // MARK: - State Management with @StateObject
    @StateObject private var realtimeManager = SimpleRealtimeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    // MARK: - Local State
    @State private var userId: String = ""
    @State private var userName: String = ""
    @State private var selectedRole: UserRole = .broadcaster
    @State private var selectedLanguage: SupportedLanguage = .english
    @State private var volumeLevel: Double = 50
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    // MARK: - Persistent State with @AppStorage demonstration
    @AppStorage("demo_last_user_id") private var lastUserId: String = ""
    @AppStorage("demo_last_user_name") private var lastUserName: String = ""
    @AppStorage("demo_preferred_language") private var preferredLanguageRaw: String = "english"
    @AppStorage("demo_last_volume") private var lastVolume: Double = 50
    @AppStorage("demo_enable_notifications") private var enableNotifications: Bool = true
    
    // MARK: - Computed Properties
    private var preferredLanguage: SupportedLanguage {
        get {
            SupportedLanguage(rawValue: preferredLanguageRaw) ?? .english
        }
        set {
            preferredLanguageRaw = newValue.rawValue
        }
    }
    
    private var isConnected: Bool {
        realtimeManager.connectionState == .connected
    }
    
    private var hasActiveSession: Bool {
        realtimeManager.currentSession != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Header Section
                    headerSection
                    
                    // MARK: - Connection Status Section
                    connectionStatusSection
                    
                    // MARK: - User Session Section
                    userSessionSection
                    
                    // MARK: - Audio Controls Section
                    audioControlsSection
                    
                    // MARK: - Volume Visualization Section
                    volumeVisualizationSection
                    
                    // MARK: - Language Settings Section
                    languageSettingsSection
                    
                    // MARK: - Demo Features Section
                    demoFeaturesSection
                    
                    // MARK: - Persistent State Demo Section
                    persistentStateSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("RealtimeKit SwiftUI Demo")
            .navigationBarTitleDisplayMode(.large)
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                setupDemo()
                restorePersistedState()
            }
            .onChange(of: selectedLanguage) { newLanguage in
                updateLanguage(newLanguage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("RealtimeKit SwiftUI Demo")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Demonstrating reactive programming and state persistence")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connection Status", systemImage: "network")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(isConnected ? "Connected (Mock)" : "Disconnected")
                    .font(.subheadline)
                
                Spacer()
                
                if hasActiveSession {
                    VStack(alignment: .trailing) {
                        Text(realtimeManager.currentSession?.userName ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(realtimeManager.currentSession?.userRole.displayName ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var userSessionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("User Session", systemImage: "person.circle")
                .font(.headline)
            
            VStack(spacing: 12) {
                TextField("User ID", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("User Name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("User Role", selection: $selectedRole) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                HStack(spacing: 12) {
                    Button(action: loginUser) {
                        Label("Login", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userId.isEmpty || userName.isEmpty || hasActiveSession)
                    
                    Button(action: logoutUser) {
                        Label("Logout", systemImage: "person.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasActiveSession)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var audioControlsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Audio Controls", systemImage: "speaker.wave.2")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(action: toggleMicrophone) {
                    Label(
                        realtimeManager.audioSettings.microphoneMuted ? "Unmute Microphone" : "Mute Microphone",
                        systemImage: realtimeManager.audioSettings.microphoneMuted ? "mic.slash" : "mic"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(realtimeManager.audioSettings.microphoneMuted ? .red : .orange)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume: \(Int(volumeLevel))")
                            .font(.subheadline)
                        Spacer()
                        Text("Persistent: \(Int(lastVolume))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $volumeLevel, in: 0...100, step: 1) {
                        Text("Volume")
                    }
                    .onChange(of: volumeLevel) { newValue in
                        updateVolume(newValue)
                    }
                }
                
                Button(action: enableVolumeIndicator) {
                    Label("Enable Volume Detection", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var volumeVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Volume Visualization", systemImage: "waveform.path.ecg")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Animated volume bars
                HStack(spacing: 4) {
                    ForEach(0..<10, id: \.self) { index in
                        VolumeBarView(
                            intensity: getVolumeIntensity(for: index),
                            isActive: !realtimeManager.volumeInfos.isEmpty
                        )
                    }
                }
                .frame(height: 60)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Speaking users display
                if !realtimeManager.speakingUsers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speaking Users:")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        ForEach(Array(realtimeManager.speakingUsers), id: \.self) { userId in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(userId)
                                    .font(.caption)
                                
                                if userId == realtimeManager.dominantSpeaker {
                                    Text("(Dominant)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var languageSettingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Language Settings", systemImage: "globe")
                .font(.headline)
            
            VStack(spacing: 12) {
                Picker("Language", selection: $selectedLanguage) {
                    Text("English").tag(SupportedLanguage.english)
                    Text("中文简体").tag(SupportedLanguage.chineseSimplified)
                    Text("中文繁體").tag(SupportedLanguage.chineseTraditional)
                    Text("日本語").tag(SupportedLanguage.japanese)
                    Text("한국어").tag(SupportedLanguage.korean)
                }
                .pickerStyle(MenuPickerStyle())
                
                HStack {
                    Text("Current Language:")
                        .font(.caption)
                    Spacer()
                    Text(localizationManager.currentLanguage.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var demoFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Demo Features", systemImage: "star.circle")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(action: startStreamPush) {
                    Label(
                        realtimeManager.streamPushState == .running ? "Stop Stream Push" : "Start Stream Push",
                        systemImage: "video.circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                
                Button(action: startMediaRelay) {
                    Label(
                        realtimeManager.mediaRelayState == .running ? "Stop Media Relay" : "Start Media Relay",
                        systemImage: "arrow.triangle.branch"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.teal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var persistentStateSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Persistent State Demo", systemImage: "externaldrive")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("@AppStorage Demonstration:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Group {
                    HStack {
                        Text("Last User ID:")
                        Spacer()
                        Text(lastUserId.isEmpty ? "None" : lastUserId)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last User Name:")
                        Spacer()
                        Text(lastUserName.isEmpty ? "None" : lastUserName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Preferred Language:")
                        Spacer()
                        Text(preferredLanguage.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Volume:")
                        Spacer()
                        Text("\(Int(lastVolume))")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                }
                .font(.caption)
                
                Button("Reset All Persistent Data") {
                    resetPersistentData()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    // MARK: - Action Methods
    
    private func setupDemo() {
        Task {
            do {
                let config = RealtimeConfig(
                    appId: "demo_app_id",
                    appCertificate: "demo_certificate",
                    rtcToken: "demo_rtc_token",
                    rtmToken: "demo_rtm_token"
                )
                
                try await realtimeManager.configure(provider: .mock, config: config)
                
            } catch {
                showAlert(title: "Configuration Error", message: error.localizedDescription)
            }
        }
    }
    
    private func restorePersistedState() {
        // Restore from @AppStorage
        userId = lastUserId
        userName = lastUserName
        selectedLanguage = preferredLanguage
        volumeLevel = lastVolume
        
        // Update localization
        localizationManager.setCurrentLanguage(selectedLanguage)
    }
    
    private func loginUser() {
        Task {
            do {
                try await realtimeManager.loginUser(
                    userId: userId,
                    userName: userName,
                    userRole: selectedRole
                )
                
                // Save to persistent storage
                lastUserId = userId
                lastUserName = userName
                
                showAlert(title: "Success", message: "Logged in successfully!")
                
            } catch {
                showAlert(title: "Login Error", message: error.localizedDescription)
            }
        }
    }
    
    private func logoutUser() {
        Task {
            do {
                try await realtimeManager.logoutUser()
                showAlert(title: "Success", message: "Logged out successfully!")
                
            } catch {
                showAlert(title: "Logout Error", message: error.localizedDescription)
            }
        }
    }
    
    private func toggleMicrophone() {
        Task {
            do {
                let currentlyMuted = realtimeManager.audioSettings.microphoneMuted
                try await realtimeManager.muteMicrophone(!currentlyMuted)
                
            } catch {
                showAlert(title: "Audio Error", message: error.localizedDescription)
            }
        }
    }
    
    private func updateVolume(_ volume: Double) {
        lastVolume = volume
        
        Task {
            do {
                try await realtimeManager.setAudioMixingVolume(Int(volume))
                
            } catch {
                showAlert(title: "Volume Error", message: error.localizedDescription)
            }
        }
    }
    
    private func enableVolumeIndicator() {
        Task {
            do {
                let config = VolumeDetectionConfig()
                try await realtimeManager.enableVolumeIndicator(config: config)
                
                showAlert(title: "Volume Detection", message: "Volume detection enabled!")
                
            } catch {
                showAlert(title: "Volume Detection Error", message: error.localizedDescription)
            }
        }
    }
    
    private func updateLanguage(_ language: SupportedLanguage) {
        preferredLanguage = language
        localizationManager.setCurrentLanguage(language)
    }
    
    private func startStreamPush() {
        Task {
            do {
                if realtimeManager.streamPushState == .running {
                    try await realtimeManager.stopStreamPush()
                } else {
                    let config = StreamPushConfig(
                        pushURL: "rtmp://demo.example.com/live/stream",
                        width: 1280,
                        height: 720,
                        videoBitrate: 2000,
                        videoFramerate: 30,
                        audioSampleRate: 44100,
                        audioBitrate: 128,
                        audioChannels: 2
                    )
                    
                    try await realtimeManager.startStreamPush(config: config)
                }
                
                let message = realtimeManager.streamPushState == .running ? 
                    "Stream push started!" : "Stream push stopped!"
                showAlert(title: "Stream Push", message: message)
                
            } catch {
                showAlert(title: "Stream Push Error", message: error.localizedDescription)
            }
        }
    }
    
    private func startMediaRelay() {
        Task {
            do {
                if realtimeManager.mediaRelayState == .running {
                    try await realtimeManager.stopMediaRelay()
                } else {
                    let config = MediaRelayConfig(
                        sourceChannelName: "source_channel",
                        sourceChannelToken: "source_token",
                        destinationChannels: [
                            MediaRelayChannelInfo(
                                channelName: "dest_channel_1",
                                channelToken: "dest_token_1",
                                uid: 12345
                            )
                        ]
                    )
                    
                    try await realtimeManager.startMediaRelay(config: config)
                }
                
                let message = realtimeManager.mediaRelayState == .running ? 
                    "Media relay started!" : "Media relay stopped!"
                showAlert(title: "Media Relay", message: message)
                
            } catch {
                showAlert(title: "Media Relay Error", message: error.localizedDescription)
            }
        }
    }
    
    private func resetPersistentData() {
        lastUserId = ""
        lastUserName = ""
        preferredLanguageRaw = "english"
        lastVolume = 50
        enableNotifications = true
        
        // Reset UI state
        userId = ""
        userName = ""
        selectedLanguage = .english
        volumeLevel = 50
        
        showAlert(title: "Reset Complete", message: "All persistent data has been reset!")
    }
    
    private func getVolumeIntensity(for index: Int) -> Double {
        if realtimeManager.volumeInfos.isEmpty {
            // Show idle animation
            let phase = Double(index) * 0.3 + Date().timeIntervalSince1970 * 2
            return (sin(phase) + 1) * 0.1
        } else {
            // Show actual volume data
            let totalVolume = realtimeManager.volumeInfos.reduce(0) { $0 + $1.volume }
            let averageVolume = totalVolume / Float(realtimeManager.volumeInfos.count)
            let speakingCount = realtimeManager.speakingUsers.count
            
            let baseIntensity = Double(averageVolume) * 0.8
            let speakingBoost = Double(speakingCount) * 0.1
            let waveOffset = sin(Double(index) * .pi * 2 + Date().timeIntervalSince1970 * 3) * 0.2
            
            return max(0, min(1, baseIntensity + speakingBoost + waveOffset))
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Volume Bar View

struct VolumeBarView: View {
    let intensity: Double
    let isActive: Bool
    
    var body: some View {
        Rectangle()
            .fill(barColor)
            .frame(width: 8)
            .frame(maxHeight: .infinity)
            .scaleEffect(y: max(0.1, intensity), anchor: .bottom)
            .animation(.easeInOut(duration: 0.1), value: intensity)
    }
    
    private var barColor: Color {
        if !isActive {
            return .gray
        } else if intensity > 0.7 {
            return .red
        } else if intensity > 0.4 {
            return .orange
        } else if intensity > 0.1 {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}