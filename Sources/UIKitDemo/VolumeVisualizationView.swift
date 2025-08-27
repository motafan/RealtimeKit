import UIKit
import RealtimeCore

/// Custom UIView for visualizing volume levels with wave animation
class VolumeVisualizationView: UIView {
    
    // MARK: - Properties
    private var volumeInfos: [UserVolumeInfo] = []
    private var volumeBars: [VolumeBarView] = []
    private let maxBars = 10
    private let barSpacing: CGFloat = 4
    
    // Animation properties
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 8
        
        setupVolumeBars()
        startAnimation()
    }
    
    private func setupVolumeBars() {
        // Create volume bars
        for i in 0..<maxBars {
            let barView = VolumeBarView()
            barView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(barView)
            volumeBars.append(barView)
        }
        
        layoutVolumeBars()
    }
    
    private func layoutVolumeBars() {
        guard !volumeBars.isEmpty else { return }
        
        let totalSpacing = CGFloat(volumeBars.count - 1) * barSpacing
        let availableWidth = bounds.width - 32 // 16pt padding on each side
        let barWidth = (availableWidth - totalSpacing) / CGFloat(volumeBars.count)
        
        for (index, barView) in volumeBars.enumerated() {
            let xPosition = 16 + CGFloat(index) * (barWidth + barSpacing)
            
            NSLayoutConstraint.activate([
                barView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xPosition),
                barView.widthAnchor.constraint(equalToConstant: barWidth),
                barView.centerYAnchor.constraint(equalTo: centerYAnchor),
                barView.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Re-layout bars when view size changes
        for barView in volumeBars {
            barView.removeFromSuperview()
        }
        volumeBars.removeAll()
        
        setupVolumeBars()
    }
    
    // MARK: - Public Methods
    func updateVolumeInfos(_ volumeInfos: [UserVolumeInfo]) {
        self.volumeInfos = volumeInfos
        updateVolumeVisualization()
    }
    
    // MARK: - Private Methods
    private func updateVolumeVisualization() {
        guard !volumeInfos.isEmpty else {
            // Show idle animation when no volume data
            showIdleAnimation()
            return
        }
        
        // Calculate average volume and speaking users
        let totalVolume = volumeInfos.reduce(0) { $0 + $1.volume }
        let averageVolume = totalVolume / Float(volumeInfos.count)
        let speakingCount = volumeInfos.filter { $0.isSpeaking }.count
        
        // Update bars based on volume data
        for (index, barView) in volumeBars.enumerated() {
            let normalizedIndex = Float(index) / Float(volumeBars.count - 1)
            let barIntensity = calculateBarIntensity(
                averageVolume: averageVolume,
                speakingCount: speakingCount,
                barIndex: normalizedIndex
            )
            
            barView.setIntensity(barIntensity, animated: true)
        }
    }
    
    private func calculateBarIntensity(averageVolume: Float, speakingCount: Int, barIndex: Float) -> Float {
        // Create wave-like visualization based on volume and speaking users
        let baseIntensity = averageVolume * 0.8
        let speakingBoost = Float(speakingCount) * 0.1
        
        // Add wave effect
        let waveOffset = sin(barIndex * .pi * 2 + Float(CACurrentMediaTime()) * 3) * 0.2
        
        let intensity = baseIntensity + speakingBoost + waveOffset
        return max(0, min(1, intensity))
    }
    
    private func showIdleAnimation() {
        // Show subtle idle animation when no volume data
        for (index, barView) in volumeBars.enumerated() {
            let phase = Float(index) * 0.3 + Float(CACurrentMediaTime()) * 2
            let intensity = (sin(phase) + 1) * 0.1 // Very subtle animation
            barView.setIntensity(intensity, animated: true)
        }
    }
    
    private func startAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
        displayLink?.add(to: .main, forMode: .common)
        animationStartTime = CACurrentMediaTime()
    }
    
    @objc private func animationTick() {
        // Update animation if no recent volume data
        if volumeInfos.isEmpty || 
           volumeInfos.allSatisfy({ Date().timeIntervalSince($0.timestamp) > 1.0 }) {
            showIdleAnimation()
        }
    }
    
    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - VolumeBarView
class VolumeBarView: UIView {
    
    private let barLayer = CALayer()
    private let backgroundLayer = CALayer()
    private var currentIntensity: Float = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        // Background layer
        backgroundLayer.backgroundColor = UIColor.systemGray4.cgColor
        backgroundLayer.cornerRadius = 2
        layer.addSublayer(backgroundLayer)
        
        // Active bar layer
        barLayer.backgroundColor = UIColor.systemBlue.cgColor
        barLayer.cornerRadius = 2
        layer.addSublayer(barLayer)
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        
        backgroundLayer.frame = bounds
        updateBarFrame()
    }
    
    func setIntensity(_ intensity: Float, animated: Bool) {
        currentIntensity = max(0, min(1, intensity))
        
        if animated {
            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
                self.updateBarFrame()
                self.updateBarColor()
            }
        } else {
            updateBarFrame()
            updateBarColor()
        }
    }
    
    private func updateBarFrame() {
        let barHeight = bounds.height * CGFloat(currentIntensity)
        let barY = bounds.height - barHeight
        
        barLayer.frame = CGRect(
            x: 0,
            y: barY,
            width: bounds.width,
            height: barHeight
        )
    }
    
    private func updateBarColor() {
        // Change color based on intensity
        let color: UIColor
        
        if currentIntensity > 0.7 {
            color = .systemRed // High volume
        } else if currentIntensity > 0.4 {
            color = .systemOrange // Medium volume
        } else if currentIntensity > 0.1 {
            color = .systemBlue // Low volume
        } else {
            color = .systemGray // Very low/no volume
        }
        
        barLayer.backgroundColor = color.cgColor
    }
}