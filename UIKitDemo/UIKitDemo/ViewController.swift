//
//  ViewController.swift
//  UIKitDemo
//
//  Created by Sondra on 8/27/25.
//

import UIKit
import RealtimeKit

class ViewController: UIViewController {
    
    // MARK: - Properties
    private let realtimeManager = RealtimeManager.shared
    
    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // Header Section
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let languageButton = UIButton(type: .system)
    
    // User Session Section
    private let userSectionView = UIView()
    private let userTitleLabel = UILabel()
    private let userRoleLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)
    
    // Audio Controls Section
    private let audioSectionView = UIView()
    private let audioTitleLabel = UILabel()
    private let volumeSlider = UISlider()
    private let volumeLabel = UILabel()
    private let muteButton = UIButton(type: .system)
    
    // Volume Indicator Section
    private let volumeIndicatorView = VolumeIndicatorView()
    
    // Connection Section
    private let connectionSectionView = UIView()
    private let connectionTitleLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    
    // Advanced Features Section
    private let advancedSectionView = UIView()
    private let advancedTitleLabel = UILabel()
    private let streamPushButton = UIButton(type: .system)
    private let mediaRelayButton = UIButton(type: .system)
    
    // Storage Demo Section
    private let storageSectionView = UIView()
    private let storageTitleLabel = UILabel()
    private let saveStateButton = UIButton(type: .system)
    private let restoreStateButton = UIButton(type: .system)
    private let clearStateButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupObservers()
        updateUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.distribution = .fill
        
        // Setup header
        setupHeaderSection()
        
        // Setup user session section
        setupUserSessionSection()
        
        // Setup audio controls section
        setupAudioControlsSection()
        
        // Setup volume indicator section
        setupVolumeIndicatorSection()
        
        // Setup connection section
        setupConnectionSection()
        
        // Setup advanced features section
        setupAdvancedFeaturesSection()
        
        // Setup storage demo section
        setupStorageDemoSection()
        
        // Add to view hierarchy
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Add sections to stack view
        stackView.addArrangedSubview(createSectionContainer(titleLabel: titleLabel, contentView: UIView()))
        stackView.addArrangedSubview(createSectionContainer(titleLabel: userTitleLabel, contentView: userSectionView))
        stackView.addArrangedSubview(createSectionContainer(titleLabel: audioTitleLabel, contentView: audioSectionView))
        stackView.addArrangedSubview(volumeIndicatorView)
        stackView.addArrangedSubview(createSectionContainer(titleLabel: connectionTitleLabel, contentView: connectionSectionView))
        stackView.addArrangedSubview(createSectionContainer(titleLabel: advancedTitleLabel, contentView: advancedSectionView))
        stackView.addArrangedSubview(createSectionContainer(titleLabel: storageTitleLabel, contentView: storageSectionView))
    }
    
    private func setupHeaderSection() {
        titleLabel.text = LocalizationManager.shared.localizedString(for: "demo.title")
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        
        statusLabel.text = LocalizationManager.shared.localizedString(for: "demo.status.disconnected")
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemRed
        
        languageButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.language.switch"), for: .normal)
        languageButton.addTarget(self, action: #selector(languageButtonTapped), for: .touchUpInside)
    }
    
    private func setupUserSessionSection() {
        userTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.user.title")
        userTitleLabel.font = .boldSystemFont(ofSize: 18)
        
        userRoleLabel.text = LocalizationManager.shared.localizedString(for: "demo.user.not_logged_in")
        userRoleLabel.font = .systemFont(ofSize: 14)
        userRoleLabel.textColor = .systemGray
        
        loginButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.user.login"), for: .normal)
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        
        logoutButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.user.logout"), for: .normal)
        logoutButton.addTarget(self, action: #selector(logoutButtonTapped), for: .touchUpInside)
        logoutButton.isEnabled = false
        
        let buttonStack = UIStackView(arrangedSubviews: [loginButton, logoutButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        
        let userStack = UIStackView(arrangedSubviews: [userRoleLabel, buttonStack])
        userStack.axis = .vertical
        userStack.spacing = 10
        
        userSectionView.addSubview(userStack)
        userStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            userStack.topAnchor.constraint(equalTo: userSectionView.topAnchor),
            userStack.leadingAnchor.constraint(equalTo: userSectionView.leadingAnchor),
            userStack.trailingAnchor.constraint(equalTo: userSectionView.trailingAnchor),
            userStack.bottomAnchor.constraint(equalTo: userSectionView.bottomAnchor)
        ])
    }
    
    private func setupAudioControlsSection() {
        audioTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.audio.title")
        audioTitleLabel.font = .boldSystemFont(ofSize: 18)
        
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 100
        volumeSlider.value = Float(realtimeManager.audioSettings.playbackSignalVolume)
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged), for: .valueChanged)
        
        volumeLabel.text = "\(LocalizationManager.shared.localizedString(for: "demo.audio.volume")): \(Int(volumeSlider.value))"
        volumeLabel.font = .systemFont(ofSize: 14)
        
        muteButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.audio.mute"), for: .normal)
        muteButton.addTarget(self, action: #selector(muteButtonTapped), for: .touchUpInside)
        
        let audioStack = UIStackView(arrangedSubviews: [volumeLabel, volumeSlider, muteButton])
        audioStack.axis = .vertical
        audioStack.spacing = 10
        
        audioSectionView.addSubview(audioStack)
        audioStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            audioStack.topAnchor.constraint(equalTo: audioSectionView.topAnchor),
            audioStack.leadingAnchor.constraint(equalTo: audioSectionView.leadingAnchor),
            audioStack.trailingAnchor.constraint(equalTo: audioSectionView.trailingAnchor),
            audioStack.bottomAnchor.constraint(equalTo: audioSectionView.bottomAnchor)
        ])
    }
    
    private func setupVolumeIndicatorSection() {
        volumeIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        volumeIndicatorView.backgroundColor = .systemGray6
        volumeIndicatorView.layer.cornerRadius = 8
        
        NSLayoutConstraint.activate([
            volumeIndicatorView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func setupConnectionSection() {
        connectionTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.connection.title")
        connectionTitleLabel.font = .boldSystemFont(ofSize: 18)
        
        connectButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.connection.connect"), for: .normal)
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        
        disconnectButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.connection.disconnect"), for: .normal)
        disconnectButton.addTarget(self, action: #selector(disconnectButtonTapped), for: .touchUpInside)
        disconnectButton.isEnabled = false
        
        let connectionStack = UIStackView(arrangedSubviews: [connectButton, disconnectButton])
        connectionStack.axis = .horizontal
        connectionStack.spacing = 10
        connectionStack.distribution = .fillEqually
        
        connectionSectionView.addSubview(connectionStack)
        connectionStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            connectionStack.topAnchor.constraint(equalTo: connectionSectionView.topAnchor),
            connectionStack.leadingAnchor.constraint(equalTo: connectionSectionView.leadingAnchor),
            connectionStack.trailingAnchor.constraint(equalTo: connectionSectionView.trailingAnchor),
            connectionStack.bottomAnchor.constraint(equalTo: connectionSectionView.bottomAnchor)
        ])
    }
    
    private func setupAdvancedFeaturesSection() {
        advancedTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.advanced.title")
        advancedTitleLabel.font = .boldSystemFont(ofSize: 18)
        
        streamPushButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.advanced.stream_push"), for: .normal)
        streamPushButton.addTarget(self, action: #selector(streamPushButtonTapped), for: .touchUpInside)
        
        mediaRelayButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.advanced.media_relay"), for: .normal)
        mediaRelayButton.addTarget(self, action: #selector(mediaRelayButtonTapped), for: .touchUpInside)
        
        let advancedStack = UIStackView(arrangedSubviews: [streamPushButton, mediaRelayButton])
        advancedStack.axis = .horizontal
        advancedStack.spacing = 10
        advancedStack.distribution = .fillEqually
        
        advancedSectionView.addSubview(advancedStack)
        advancedStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            advancedStack.topAnchor.constraint(equalTo: advancedSectionView.topAnchor),
            advancedStack.leadingAnchor.constraint(equalTo: advancedSectionView.leadingAnchor),
            advancedStack.trailingAnchor.constraint(equalTo: advancedSectionView.trailingAnchor),
            advancedStack.bottomAnchor.constraint(equalTo: advancedSectionView.bottomAnchor)
        ])
    }
    
    private func setupStorageDemoSection() {
        storageTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.storage.title")
        storageTitleLabel.font = .boldSystemFont(ofSize: 18)
        
        saveStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.save"), for: .normal)
        saveStateButton.addTarget(self, action: #selector(saveStateButtonTapped), for: .touchUpInside)
        
        restoreStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.restore"), for: .normal)
        restoreStateButton.addTarget(self, action: #selector(restoreStateButtonTapped), for: .touchUpInside)
        
        clearStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.clear"), for: .normal)
        clearStateButton.addTarget(self, action: #selector(clearStateButtonTapped), for: .touchUpInside)
        
        let storageStack = UIStackView(arrangedSubviews: [saveStateButton, restoreStateButton, clearStateButton])
        storageStack.axis = .horizontal
        storageStack.spacing = 8
        storageStack.distribution = .fillEqually
        
        storageSectionView.addSubview(storageStack)
        storageStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            storageStack.topAnchor.constraint(equalTo: storageSectionView.topAnchor),
            storageStack.leadingAnchor.constraint(equalTo: storageSectionView.leadingAnchor),
            storageStack.trailingAnchor.constraint(equalTo: storageSectionView.trailingAnchor),
            storageStack.bottomAnchor.constraint(equalTo: storageSectionView.bottomAnchor)
        ])
    }
    
    private func createSectionContainer(titleLabel: UILabel, contentView: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.systemGray4.cgColor
        
        let headerView = UIView()
        headerView.backgroundColor = .systemGray6
        
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(headerView)
        container.addSubview(contentView)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Header constraints
            headerView.topAnchor.constraint(equalTo: container.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Title label constraints
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupObservers() {
        // Observe connection state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionStateChanged),
            name: .realtimeConnectionStateChanged,
            object: nil
        )
        
        // Observe language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .localizationLanguageChanged,
            object: nil
        )
        
        // Observe user session changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userSessionChanged),
            name: .realtimeUserSessionChanged,
            object: nil
        )
    }
    
    // MARK: - Actions
    @objc private func languageButtonTapped() {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.language.select"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        for language in SupportedLanguage.allCases {
            let action = UIAlertAction(title: language.demoDisplayName, style: .default) { _ in
                Task  { @MainActor in
                    await LocalizationManager.shared.setLanguage(language)
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.cancel"), style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = languageButton
            popover.sourceRect = languageButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func loginButtonTapped() {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.user.select_role"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        for role in UserRole.allCases {
            let action = UIAlertAction(title: role.demoDisplayName, style: .default) { _ in
                Task {
                   try await self.realtimeManager.loginUser(userId: "demo_user", userName: "demo_user", userRole: role)
                }
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.cancel"), style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = loginButton
            popover.sourceRect = loginButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func logoutButtonTapped() {
        Task {
           try await realtimeManager.logoutUser()
        }
    }
    
    @objc private func volumeSliderChanged() {
        let volume = Int(volumeSlider.value)
        volumeLabel.text = "\(LocalizationManager.shared.localizedString(for: "demo.audio.volume")): \(volume)"
        
        Task {
            try await realtimeManager.setPlaybackSignalVolume(volume)
        }
    }
    
    @objc private func muteButtonTapped() {
        Task {
            let isMuted = realtimeManager.audioSettings.microphoneMuted
            try await realtimeManager.muteMicrophone(!isMuted)
            updateMuteButton()
        }
    }
    
    @objc private func connectButtonTapped() {
        Task {
            do {
                try await realtimeManager.joinRoom(roomId: "demo_channel")
            } catch {
                showError(error)
            }
        }
    }
    
    @objc private func disconnectButtonTapped() {
        Task {
            do {
                try await realtimeManager.leaveRoom()
            } catch {
                showError(error)
            }
        }
    }
    
    @objc private func streamPushButtonTapped() {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.advanced.stream_push"),
            message: LocalizationManager.shared.localizedString(for: "demo.advanced.stream_push_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.ok"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func mediaRelayButtonTapped() {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.advanced.media_relay"),
            message: LocalizationManager.shared.localizedString(for: "demo.advanced.media_relay_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.ok"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func saveStateButtonTapped() {
        // Demonstrate @RealtimeStorage by manually triggering a save
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.storage.save"),
            message: LocalizationManager.shared.localizedString(for: "demo.storage.save_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.ok"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func restoreStateButtonTapped() {
        // Demonstrate state restoration
        volumeSlider.value = Float(realtimeManager.audioSettings.playbackSignalVolume)
        volumeSliderChanged()
        updateUI()
        
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.storage.restore"),
            message: LocalizationManager.shared.localizedString(for: "demo.storage.restore_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.ok"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func clearStateButtonTapped() {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.storage.clear"),
            message: LocalizationManager.shared.localizedString(for: "demo.storage.clear_message"),
            preferredStyle: .alert
        )
        
        let clearAction = UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.storage.clear"), style: .destructive) { _ in
            // Clear storage demonstration
            Task {
                try? await self.realtimeManager.logoutUser()
                try? await self.realtimeManager.setPlaybackSignalVolume(50)
                try? await self.realtimeManager.muteMicrophone(false)
                self.updateUI()
            }
        }
        
        alert.addAction(clearAction)
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.cancel"), style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Observers
    @objc private func connectionStateChanged() {
        DispatchQueue.main.async {
            self.updateConnectionUI()
        }
    }
    
    @objc private func languageChanged() {
        DispatchQueue.main.async {
            self.updateLocalizedStrings()
        }
    }
    
    @objc private func userSessionChanged() {
        DispatchQueue.main.async {
            self.updateUserSessionUI()
        }
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        updateConnectionUI()
        updateUserSessionUI()
        updateMuteButton()
    }
    
    private func updateConnectionUI() {
        let isConnected = realtimeManager.connectionState == .connected
        
        statusLabel.text = isConnected ? 
            LocalizationManager.shared.localizedString(for: "demo.status.connected") :
            LocalizationManager.shared.localizedString(for: "demo.status.disconnected")
        statusLabel.textColor = isConnected ? .systemGreen : .systemRed
        
        connectButton.isEnabled = !isConnected
        disconnectButton.isEnabled = isConnected
        streamPushButton.isEnabled = isConnected
        mediaRelayButton.isEnabled = isConnected
    }
    
    private func updateUserSessionUI() {
        let isLoggedIn = realtimeManager.currentSession != nil
        
        if let currentUserRole = realtimeManager.currentUserRole {
            userRoleLabel.text = "\(LocalizationManager.shared.localizedString(for: "demo.user.role")): \(currentUserRole.demoDisplayName)"
            userRoleLabel.textColor = .label
        } else {
            userRoleLabel.text = LocalizationManager.shared.localizedString(for: "demo.user.not_logged_in")
            userRoleLabel.textColor = .systemGray
        }
        
        loginButton.isEnabled = !isLoggedIn
        logoutButton.isEnabled = isLoggedIn
    }
    
    private func updateMuteButton() {
        let isMuted = realtimeManager.audioSettings.microphoneMuted
        muteButton.setTitle(
            isMuted ? 
                LocalizationManager.shared.localizedString(for: "demo.audio.unmute") :
                LocalizationManager.shared.localizedString(for: "demo.audio.mute"),
            for: .normal
        )
    }
    
    private func updateLocalizedStrings() {
        titleLabel.text = LocalizationManager.shared.localizedString(for: "demo.title")
        languageButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.language.switch"), for: .normal)
        
        userTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.user.title")
        loginButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.user.login"), for: .normal)
        logoutButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.user.logout"), for: .normal)
        
        audioTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.audio.title")
        volumeLabel.text = "\(LocalizationManager.shared.localizedString(for: "demo.audio.volume")): \(Int(volumeSlider.value))"
        
        connectionTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.connection.title")
        connectButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.connection.connect"), for: .normal)
        disconnectButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.connection.disconnect"), for: .normal)
        
        advancedTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.advanced.title")
        streamPushButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.advanced.stream_push"), for: .normal)
        mediaRelayButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.advanced.media_relay"), for: .normal)
        
        storageTitleLabel.text = LocalizationManager.shared.localizedString(for: "demo.storage.title")
        saveStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.save"), for: .normal)
        restoreStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.restore"), for: .normal)
        clearStateButton.setTitle(LocalizationManager.shared.localizedString(for: "demo.storage.clear"), for: .normal)
        
        updateConnectionUI()
        updateUserSessionUI()
        updateMuteButton()
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: LocalizationManager.shared.localizedString(for: "demo.error.title"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LocalizationManager.shared.localizedString(for: "demo.ok"), style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

