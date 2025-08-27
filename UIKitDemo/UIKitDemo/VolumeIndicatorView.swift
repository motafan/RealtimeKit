//
//  VolumeIndicatorView.swift
//  UIKitDemo
//
//  Created by Kiro on 8/27/25.
//

import UIKit
import RealtimeKit

class VolumeIndicatorView: UIView {
    
    // MARK: - Properties
    private let titleLabel = UILabel()
    private let volumeBarsContainer = UIView()
    private let speakingIndicator = UIView()
    private let speakingLabel = UILabel()
    
    private var volumeBars: [UIView] = []
    private let numberOfBars = 10
    
    private var currentVolume: Float = 0.0
    private var isSpeaking: Bool = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupVolumeIndicator()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupVolumeIndicator()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Title
        titleLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.indicator")
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .center
        
        // Speaking indicator
        speakingIndicator.backgroundColor = .systemGray4
        speakingIndicator.layer.cornerRadius = 8
        
        speakingLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.not_speaking")
        speakingLabel.font = .systemFont(ofSize: 12)
        speakingLabel.textAlignment = .center
        speakingLabel.textColor = .systemGray
        
        // Add subviews
        addSubview(titleLabel)
        addSubview(volumeBarsContainer)
        addSubview(speakingIndicator)
        speakingIndicator.addSubview(speakingLabel)
        
        // Setup constraints
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeBarsContainer.translatesAutoresizingMaskIntoConstraints = false
        speakingIndicator.translatesAutoresizingMaskIntoConstraints = false
        speakingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Volume bars container
            volumeBarsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            volumeBarsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            volumeBarsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            volumeBarsContainer.heightAnchor.constraint(equalToConstant: 30),
            
            // Speaking indicator
            speakingIndicator.topAnchor.constraint(equalTo: volumeBarsContainer.bottomAnchor, constant: 12),
            speakingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            speakingIndicator.widthAnchor.constraint(equalToConstant: 120),
            speakingIndicator.heightAnchor.constraint(equalToConstant: 24),
            speakingIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // Speaking label
            speakingLabel.centerXAnchor.constraint(equalTo: speakingIndicator.centerXAnchor),
            speakingLabel.centerYAnchor.constraint(equalTo: speakingIndicator.centerYAnchor)
        ])
    }
    
    private func setupVolumeIndicator() {
        // Create volume bars
        for i in 0..<numberOfBars {
            let bar = UIView()
            bar.backgroundColor = .systemGray4
            bar.layer.cornerRadius = 2
            volumeBars.append(bar)
            volumeBarsContainer.addSubview(bar)
            
            bar.translatesAutoresizingMaskIntoConstraints = false
            
            let barWidth: CGFloat = 20
            let barSpacing: CGFloat = 4
            let totalWidth = CGFloat(numberOfBars) * barWidth + CGFloat(numberOfBars - 1) * barSpacing
            let startX = -totalWidth / 2
            
            NSLayoutConstraint.activate([
                bar.centerYAnchor.constraint(equalTo: volumeBarsContainer.centerYAnchor),
                bar.centerXAnchor.constraint(equalTo: volumeBarsContainer.centerXAnchor, constant: startX + CGFloat(i) * (barWidth + barSpacing) + barWidth / 2),
                bar.widthAnchor.constraint(equalToConstant: barWidth),
                bar.heightAnchor.constraint(equalToConstant: CGFloat(4 + i * 2)) // Increasing height
            ])
        }
        
        // Start simulating volume changes
        startVolumeSimulation()
    }
    
    // MARK: - Volume Simulation
    private func startVolumeSimulation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateVolumeChange()
            }
        }
    }
    
    private func simulateVolumeChange() {
        // Simulate random volume changes
        let randomVolume = Float.random(in: 0...100)
        let randomSpeaking = randomVolume > 30
        
        updateVolume(randomVolume, isSpeaking: randomSpeaking)
    }
    
    // MARK: - Public Methods
    func updateVolume(_ volume: Float, isSpeaking: Bool) {
        self.currentVolume = volume
        self.isSpeaking = isSpeaking
        
        DispatchQueue.main.async {
            self.updateVolumeDisplay()
            self.updateSpeakingIndicator()
        }
    }
    
    // MARK: - Private Methods
    private func updateVolumeDisplay() {
        let normalizedVolume = currentVolume / 100.0
        let activeBars = Int(normalizedVolume * Float(numberOfBars))
        
        for (index, bar) in volumeBars.enumerated() {
            if index < activeBars {
                // Active bar - use gradient color based on volume level
                if normalizedVolume < 0.3 {
                    bar.backgroundColor = .systemGreen
                } else if normalizedVolume < 0.7 {
                    bar.backgroundColor = .systemYellow
                } else {
                    bar.backgroundColor = .systemRed
                }
                
                // Add animation
                UIView.animate(withDuration: 0.1) {
                    bar.transform = CGAffineTransform(scaleX: 1.0, y: 1.2)
                }
            } else {
                // Inactive bar
                bar.backgroundColor = .systemGray4
                UIView.animate(withDuration: 0.1) {
                    bar.transform = .identity
                }
            }
        }
    }
    
    private func updateSpeakingIndicator() {
        if isSpeaking {
            speakingIndicator.backgroundColor = .systemGreen
            speakingLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.speaking")
            speakingLabel.textColor = .white
            
            // Add pulsing animation
            UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.speakingIndicator.alpha = 0.7
            })
        } else {
            speakingIndicator.backgroundColor = .systemGray4
            speakingLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.not_speaking")
            speakingLabel.textColor = .systemGray
            
            // Remove animation
            speakingIndicator.layer.removeAllAnimations()
            speakingIndicator.alpha = 1.0
        }
    }
}

// MARK: - Localization Support
extension VolumeIndicatorView {
    func updateLocalizedStrings() {
        titleLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.indicator")
        
        if isSpeaking {
            speakingLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.speaking")
        } else {
            speakingLabel.text = LocalizationManager.shared.localizedString(for: "demo.volume.not_speaking")
        }
    }
}