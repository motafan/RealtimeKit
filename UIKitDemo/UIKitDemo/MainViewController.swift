import UIKit
import RealtimeCore
import RealtimeMocking

/// Main view controller demonstrating RealtimeKit UIKit integration
class MainViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // User Session Section
    private let userSessionLabel = UILabel()
    private let userIdTextField = UITextField()
    private let userNameTextField = UITextField()
    private let userRoleSegmentedControl = UISegmentedControl(items: ["Broadcaster", "Audience", "Co-Host", "Moderator"])
    private let loginButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)
    
    // Audio Settings Section
    private let audioSettingsLabel = UILabel()
    private let muteButton = UIButton(type: .system)
    private let volumeSlider = UISlider()
    private let volumeLabel = UILabel()
    
    // Volume Indicator Section
    private let volumeIndicatorLabel = UILabel()
    private let enableVolumeButton = UIButton(type: .system)
    private let volumeVisualizationView = VolumeVisualizationView()
    
    // Language Settings Section
    private let languageLabel = UILabel()
    private let languageSegmentedControl = UISegmentedControl(items: ["English", "中文简体", "中文繁體", "日本語", "한국어"])
    
    // Status Section
    private let statusLabel = UILabel()
    private let connectionStatusLabel = UILabel()
    
    // Demo Features Section
    private let demoFeaturesLabel = UILabel()
    private let streamPushButton = UIButton(type: .system)
    private let mediaRelayButton = UIButton(type: .system)
    
    // MARK: - Properties with persistent storage demonstration
    private var userPreferences: UserPreferences = UserPreferences()
    private var lastSession: UserSession?
    private var authToken: String?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRealtimeKit()
        restorePersistedState()
        updateLocalizedTexts()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "RealtimeKit UIKit Demo"
        view.backgroundColor = .systemBackground
        
        setupScrollView()
        setupStackView()
        setupUserSessionSection()
        setupAudioSettingsSection()
        setupVolumeIndicatorSection()
        setupLanguageSection()
        setupStatusSection()
        setupDemoFeaturesSection()
        setupConstraints()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    private func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
    }
    
    private func setupUserSessionSection() {
        userSessionLabel.font = .boldSystemFont(ofSize: 18)
        userSessionLabel.text = "User Session"
        
        userIdTextField.borderStyle = .roundedRect
        userIdTextField.placeholder = "Enter User ID"
        
        userNameTextField.borderStyle = .roundedRect
        userNameTextField.placeholder = "Enter User Name"
        
        userRoleSegmentedControl.selectedSegmentIndex = 0
        
        loginButton.setTitle("Login", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        logoutButton.setTitle("Logout", for: .normal)
        logoutButton.backgroundColor = .systemRed
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.layer.cornerRadius = 8
        logoutButton.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        logoutButton.isEnabled = false
        
        let sessionStackView = UIStackView(arrangedSubviews: [
            userSessionLabel, userIdTextField, userNameTextField, 
            userRoleSegmentedControl, loginButton, logoutButton
        ])
        sessionStackView.axis = .vertical
        sessionStackView.spacing = 10
        
        stackView.addArrangedSubview(sessionStackView)
    }
    
    private func setupAudioSettingsSection() {
        audioSettingsLabel.font = .boldSystemFont(ofSize: 18)
        audioSettingsLabel.text = "Audio Settings"
        
        muteButton.setTitle("Mute Microphone", for: .normal)
        muteButton.backgroundColor = .systemOrange
        muteButton.setTitleColor(.white, for: .normal)
        muteButton.layer.cornerRadius = 8
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 100
        volumeSlider.value = 50
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        
        volumeLabel.text = "Volume: 50"
        volumeLabel.textAlignment = .center
        
        let audioStackView = UIStackView(arrangedSubviews: [
            audioSettingsLabel, muteButton, volumeSlider, volumeLabel
        ])
        audioStackView.axis = .vertical
        audioStackView.spacing = 10
        
        stackView.addArrangedSubview(audioStackView)
    }
    
    private func setupVolumeIndicatorSection() {
        volumeIndicatorLabel.font = .boldSystemFont(ofSize: 18)
        volumeIndicatorLabel.text = "Volume Indicator"
        
        enableVolumeButton.setTitle("Enable Volume Detection", for: .normal)
        enableVolumeButton.backgroundColor = .systemGreen
        enableVolumeButton.setTitleColor(.white, for: .normal)
        enableVolumeButton.layer.cornerRadius = 8
        enableVolumeButton.addTarget(self, action: #selector(enableVolumeButtonTapped), for: .touchUpInside)
        
        volumeVisualizationView.backgroundColor = .systemGray6
        volumeVisualizationView.layer.cornerRadius = 8
        volumeVisualizationView.translatesAutoresizingMaskIntoConstraints = false
        volumeVisualizationView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        let volumeStackView = UIStackView(arrangedSubviews: [
            volumeIndicatorLabel, enableVolumeButton, volumeVisualizationView
        ])
        volumeStackView.axis = .vertical
        volumeStackView.spacing = 10
        
        stackView.addArrangedSubview(volumeStackView)
    }
    
    private func setupLanguageSection() {
        languageLabel.font = .boldSystemFont(ofSize: 18)
        languageLabel.text = "Language Settings"
        
        languageSegmentedControl.selectedSegmentIndex = 0
        languageSegmentedControl.addTarget(self, action: #selector(languageChanged), for: .valueChanged)
        
        let languageStackView = UIStackView(arrangedSubviews: [
            languageLabel, languageSegmentedControl
        ])
        languageStackView.axis = .vertical
        languageStackView.spacing = 10
        
        stackView.addArrangedSubview(languageStackView)
    }
    
    private func setupStatusSection() {
        statusLabel.font = .boldSystemFont(ofSize: 18)
        statusLabel.text = "Connection Status"
        
        connectionStatusLabel.text = "Disconnected"
        connectionStatusLabel.textColor = .systemRed
        connectionStatusLabel.textAlignment = .center
        
        let statusStackView = UIStackView(arrangedSubviews: [
            statusLabel, connectionStatusLabel
        ])
        statusStackView.axis = .vertical
        statusStackView.spacing = 10
        
        stackView.addArrangedSubview(statusStackView)
    }
    
    private func setupDemoFeaturesSection() {
        demoFeaturesLabel.font = .boldSystemFont(ofSize: 18)
        demoFeaturesLabel.text = "Demo Features"
        
        streamPushButton.setTitle("Start Stream Push", for: .normal)
        streamPushButton.backgroundColor = .systemPurple
        streamPushButton.setTitleColor(.white, for: .normal)
        streamPushButton.layer.cornerRadius = 8
        streamPushButton.addTarget(self, action: #selector(streamPushButtonTapped), for: .touchUpInside)
        
        mediaRelayButton.setTitle("Start Media Relay", for: .normal)
        mediaRelayButton.backgroundColor = .systemTeal
        mediaRelayButton.setTitleColor(.white, for: .normal)
        mediaRelayButton.layer.cornerRadius = 8
        mediaRelayButton.addTarget(self, action: #selector(mediaRelayButtonTapped), for: .touchUpInside)
        
        let demoStackView = UIStackView(arrangedSubviews: [
            demoFeaturesLabel, streamPushButton, mediaRelayButton
        ])
        demoStackView.axis = .vertical
        demoStackView.spacing = 10
        
        stackView.addArrangedSubview(demoStackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupRealtimeKit() {
        Task {
            do {
                // Configure RealtimeKit with Mock provider for demo
                let config = RealtimeConfig(
                    appId: "demo_app_id",
                    appCertificate: "demo_certificate",
                    rtcToken: "demo_rtc_token",
                    rtmToken: "demo_rtm_token"
                )
                
                try await SimpleRealtimeManager.shared.configure(provider: .mock, config: config)
                
                // Setup observers for state changes
                setupRealtimeObservers()
                
                await MainActor.run {
                    connectionStatusLabel.text = "Connected (Mock)"
                    connectionStatusLabel.textColor = .systemGreen
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Configuration Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setupRealtimeObservers() {
        // Setup reactive observations for SimpleRealtimeManager
        setupReactiveObservations()
    }
    
    private func restorePersistedState() {
        // Demonstrate @RealtimeStorage automatic state restoration
        userIdTextField.text = userPreferences.lastUserId
        userNameTextField.text = userPreferences.lastUserName
        volumeSlider.value = Float(userPreferences.lastVolume)
        volumeLabel.text = "Volume: \(userPreferences.lastVolume)"
        
        if let language = userPreferences.preferredLanguage {
            switch language {
            case .english: languageSegmentedControl.selectedSegmentIndex = 0
            case .chineseSimplified: languageSegmentedControl.selectedSegmentIndex = 1
            case .chineseTraditional: languageSegmentedControl.selectedSegmentIndex = 2
            case .japanese: languageSegmentedControl.selectedSegmentIndex = 3
            case .korean: languageSegmentedControl.selectedSegmentIndex = 4
            }
        }
        
        // Restore last session if available
        if let session = lastSession {
            userIdTextField.text = session.userId
            userNameTextField.text = session.userName
            
            switch session.userRole {
            case .broadcaster: userRoleSegmentedControl.selectedSegmentIndex = 0
            case .audience: userRoleSegmentedControl.selectedSegmentIndex = 1
            case .coHost: userRoleSegmentedControl.selectedSegmentIndex = 2
            case .moderator: userRoleSegmentedControl.selectedSegmentIndex = 3
            }
        }
    }
    
    private func updateLocalizedTexts() {
        // Demonstrate localization integration
        let localizationManager = LocalizationManager.shared
        
        title = localizationManager.localizedString(for: "demo.title", defaultValue: "RealtimeKit UIKit Demo")
        userSessionLabel.text = localizationManager.localizedString(for: "demo.user_session", defaultValue: "User Session")
        audioSettingsLabel.text = localizationManager.localizedString(for: "demo.audio_settings", defaultValue: "Audio Settings")
        volumeIndicatorLabel.text = localizationManager.localizedString(for: "demo.volume_indicator", defaultValue: "Volume Indicator")
        languageLabel.text = localizationManager.localizedString(for: "demo.language_settings", defaultValue: "Language Settings")
        statusLabel.text = localizationManager.localizedString(for: "demo.connection_status", defaultValue: "Connection Status")
        demoFeaturesLabel.text = localizationManager.localizedString(for: "demo.demo_features", defaultValue: "Demo Features")
    }
    
    // MARK: - Action Methods
    @objc private func loginButtonTapped() {
        guard let userId = userIdTextField.text, !userId.isEmpty,
              let userName = userNameTextField.text, !userName.isEmpty else {
            showAlert(title: "Input Error", message: "Please enter both User ID and User Name")
            return
        }
        
        let userRole = getUserRoleFromSegmentedControl()
        
        Task {
            do {
                try await SimpleRealtimeManager.shared.loginUser(userId: userId, userName: userName, userRole: userRole)
                
                // Save to persistent storage
                userPreferences.lastUserId = userId
                userPreferences.lastUserName = userName
                lastSession = UserSession(userId: userId, userName: userName, userRole: userRole)
                
                await MainActor.run {
                    loginButton.isEnabled = false
                    logoutButton.isEnabled = true
                    showAlert(title: "Success", message: "Logged in successfully!")
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Login Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func logoutButtonTapped() {
        Task {
            do {
                try await SimpleRealtimeManager.shared.logoutUser()
                
                await MainActor.run {
                    loginButton.isEnabled = true
                    logoutButton.isEnabled = false
                    lastSession = nil
                    showAlert(title: "Success", message: "Logged out successfully!")
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Logout Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func muteButtonTapped() {
        Task {
            do {
                let currentlyMuted = SimpleRealtimeManager.shared.audioSettings.microphoneMuted
                try await SimpleRealtimeManager.shared.muteMicrophone(!currentlyMuted)
                
                await MainActor.run {
                    muteButton.setTitle(currentlyMuted ? "Mute Microphone" : "Unmute Microphone", for: .normal)
                    muteButton.backgroundColor = currentlyMuted ? .systemOrange : .systemGray
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Audio Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func volumeSliderChanged() {
        let volume = Int(volumeSlider.value)
        volumeLabel.text = "Volume: \(volume)"
        
        // Save to persistent storage
        userPreferences.lastVolume = volume
        
        Task {
            do {
                try await SimpleRealtimeManager.shared.setAudioMixingVolume(volume)
            } catch {
                await MainActor.run {
                    showAlert(title: "Volume Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func enableVolumeButtonTapped() {
        Task {
            do {
                let config = VolumeDetectionConfig()
                try await SimpleRealtimeManager.shared.enableVolumeIndicator(config: config)
                
                // Setup volume visualization
                setupVolumeVisualization()
                
                await MainActor.run {
                    enableVolumeButton.setTitle("Disable Volume Detection", for: .normal)
                    enableVolumeButton.backgroundColor = .systemRed
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Volume Detection Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func languageChanged() {
        let selectedLanguage: SupportedLanguage
        
        switch languageSegmentedControl.selectedSegmentIndex {
        case 0: selectedLanguage = .english
        case 1: selectedLanguage = .chineseSimplified
        case 2: selectedLanguage = .chineseTraditional
        case 3: selectedLanguage = .japanese
        case 4: selectedLanguage = .korean
        default: selectedLanguage = .english
        }
        
        // Save preference
        userPreferences.preferredLanguage = selectedLanguage
        
        // Update localization
        LocalizationManager.shared.setCurrentLanguage(selectedLanguage)
        updateLocalizedTexts()
    }
    
    @objc private func streamPushButtonTapped() {
        Task {
            do {
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
                
                try await SimpleRealtimeManager.shared.startStreamPush(config: config)
                
                await MainActor.run {
                    streamPushButton.setTitle("Stop Stream Push", for: .normal)
                    streamPushButton.backgroundColor = .systemRed
                    showAlert(title: "Stream Push", message: "Stream push started successfully!")
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Stream Push Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func mediaRelayButtonTapped() {
        Task {
            do {
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
                
                try await SimpleRealtimeManager.shared.startMediaRelay(config: config)
                
                await MainActor.run {
                    mediaRelayButton.setTitle("Stop Media Relay", for: .normal)
                    mediaRelayButton.backgroundColor = .systemRed
                    showAlert(title: "Media Relay", message: "Media relay started successfully!")
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Media Relay Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func setupReactiveObservations() {
        // Setup reactive observations for SimpleRealtimeManager
        // This demonstrates reactive programming with UIKit
        
        // Observe session changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimpleRealtimeManagerSessionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConnectionStatus()
        }
        
        // Observe connection state changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SimpleRealtimeManagerConnectionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateConnectionStatus()
        }
    }
    
    private func updateConnectionStatus() {
        let manager = SimpleRealtimeManager.shared
        
        if let session = manager.currentSession {
            connectionStatusLabel.text = "Connected - \(session.userName) (\(session.userRole.rawValue))"
            connectionStatusLabel.textColor = .systemGreen
        } else {
            connectionStatusLabel.text = "Disconnected"
            connectionStatusLabel.textColor = .systemRed
        }
    }
    
    // MARK: - Helper Methods
    private func getUserRoleFromSegmentedControl() -> UserRole {
        switch userRoleSegmentedControl.selectedSegmentIndex {
        case 0: return .broadcaster
        case 1: return .audience
        case 2: return .coHost
        case 3: return .moderator
        default: return .audience
        }
    }
    
    private func setupVolumeVisualization() {
        // Setup volume visualization with SimpleRealtimeManager
        SimpleRealtimeManager.shared.volumeManager.onVolumeUpdate = { [weak self] volumeInfos in
            DispatchQueue.main.async {
                self?.volumeVisualizationView.updateVolumeInfos(volumeInfos)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Extensions
extension Notification.Name {
    static let realtimeManagerStateChanged = Notification.Name("RealtimeManagerStateChanged")
}