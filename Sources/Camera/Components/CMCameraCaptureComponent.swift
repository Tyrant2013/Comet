//
//  CMCameraPreviewDemo.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI
import UIKit
import Combine

public struct CMCameraCaptureConfiguration: Sendable {
    public var showZoomSlider: Bool
    public var showSwitchButton: Bool
    
    public init(showZoomSlider: Bool = true, showSwitchButton: Bool = true) {
        self.showZoomSlider = showZoomSlider
        self.showSwitchButton = showSwitchButton
    }
    
    public static let `default` = CMCameraCaptureConfiguration()
}

public final class CMCameraCaptureViewController: UIViewController {
    private let camera: CMCamera
    private let configuration: CMCameraCaptureConfiguration
    private let cameraView: CMCameraView
    
    private let statusLabel = UILabel()
    private let lensStatusLabel = UILabel()
    private let lensControl = UISegmentedControl(items: [])
    private let zoomDial = CMCameraZoomDialView()
    private let switchButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let transitionSnapshotView = UIImageView()
    
    private var zoomOptions: [CGFloat] = []
    private var cancellables: Set<AnyCancellable> = []
    private var isSwitchingCamera = false
    private var isAwaitingFirstFrameAfterSwitch = false
    private var switchTransitionToken: UUID?
    
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    public init(
        camera: CMCamera = CMCamera(),
        configuration: CMCameraCaptureConfiguration = .default
    ) {
        self.camera = camera
        self.configuration = configuration
        self.cameraView = CMCameraView(camera: camera)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        let camera = CMCamera()
        self.camera = camera
        self.configuration = .default
        self.cameraView = CMCameraView(camera: camera)
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindCameraState()
        configureCameraCallbacks()
        
        refreshLensOptions()
        refreshStatus()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        camera.start()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        camera.stop()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        lensStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        lensControl.translatesAutoresizingMaskIntoConstraints = false
        zoomDial.translatesAutoresizingMaskIntoConstraints = false
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        transitionSnapshotView.translatesAutoresizingMaskIntoConstraints = false
        
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        
        lensStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        lensStatusLabel.textColor = UIColor(white: 0.85, alpha: 1)
        lensStatusLabel.textAlignment = .center
        
        lensControl.selectedSegmentTintColor = .white
        lensControl.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        lensControl.addTarget(self, action: #selector(didTapLensControl), for: .valueChanged)
        
        zoomDial.isHidden = !configuration.showZoomSlider
        
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        switchButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera", withConfiguration: config), for: .normal)
        switchButton.tintColor = .white
        switchButton.addTarget(self, action: #selector(didTapSwitchButton), for: .touchUpInside)
        switchButton.isHidden = !configuration.showSwitchButton
        
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .white
        
        transitionSnapshotView.contentMode = .scaleAspectFill
        transitionSnapshotView.clipsToBounds = true
        transitionSnapshotView.isHidden = true
        transitionSnapshotView.alpha = 0
        
        view.addSubview(cameraView)
        view.addSubview(transitionSnapshotView)
        view.addSubview(statusLabel)
        view.addSubview(lensStatusLabel)
        view.addSubview(lensControl)
        view.addSubview(zoomDial)
        view.addSubview(switchButton)
        view.addSubview(loadingIndicator)
        
        let previewRatio = cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor, multiplier: 16.0 / 9.0)
        previewRatio.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            lensStatusLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            lensStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cameraView.topAnchor.constraint(equalTo: lensStatusLabel.bottomAnchor, constant: 10),
            cameraView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            previewRatio,
            
            transitionSnapshotView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            transitionSnapshotView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
            transitionSnapshotView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            transitionSnapshotView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            
            lensControl.topAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 16),
            lensControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            lensControl.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            lensControl.heightAnchor.constraint(equalToConstant: 36),
            zoomDial.topAnchor.constraint(equalTo: lensControl.bottomAnchor, constant: 6),
            zoomDial.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            zoomDial.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            zoomDial.heightAnchor.constraint(equalToConstant: 110),
            cameraView.bottomAnchor.constraint(lessThanOrEqualTo: lensControl.topAnchor, constant: -16),
            
            switchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            switchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 68),
            switchButton.heightAnchor.constraint(equalToConstant: 68),
            zoomDial.bottomAnchor.constraint(lessThanOrEqualTo: switchButton.topAnchor, constant: -8),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: lensControl.centerYAnchor)
        ])
        
        cameraView.onFrameRendered = { [weak self] in
            self?.handleCameraFrameRendered()
        }
        
        zoomDial.onInteractionBegan = { [weak self] in
            self?.impactFeedback.impactOccurred(intensity: 0.5)
        }
        zoomDial.onValueChanging = { [weak self] value in
            guard let self else { return }
            self.lensStatusLabel.text = "当前倍率：\(String(format: "%.1fx", value))"
            self.camera.setZoomFactor(value, rampDuration: 0.06)
        }
        zoomDial.onInteractionEnded = { [weak self] value in
            self?.snapZoomIfNeeded(value: value)
        }
        
        selectionFeedback.prepare()
        impactFeedback.prepare()
    }
    
    private func bindCameraState() {
        camera.$currentCameraPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStatus() }
            .store(in: &cancellables)
        
        camera.$currentLens
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshStatus()
                self?.refreshLensSelection()
            }
            .store(in: &cancellables)
        
        camera.$availableLenses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshLensOptions() }
            .store(in: &cancellables)
        
        camera.$currentZoomFactor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] zoom in
                guard let self else { return }
                self.refreshStatus()
                self.updateDialValue(zoom)
                self.refreshLensSelection()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest(camera.$minZoomFactor, camera.$maxZoomFactor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] minZoom, maxZoom in
                self?.configureDial(minZoom: minZoom, maxZoom: maxZoom)
            }
            .store(in: &cancellables)
    }
    
    private func configureCameraCallbacks() {
        camera.onError = { [weak self] message in
            guard let self = self else { return }
            let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func refreshLensOptions() {
        let options = camera.getAvailableZoomPresets()
        if options == zoomOptions {
            refreshLensSelection()
            refreshSwitchButtonState()
            return
        }
        
        zoomOptions = options
        lensControl.removeAllSegments()
        for (index, zoom) in options.enumerated() {
            lensControl.insertSegment(withTitle: zoomLabel(zoom), at: index, animated: false)
        }
        zoomDial.presetValues = options
        
        lensControl.isEnabled = !options.isEmpty
        refreshLensSelection()
        refreshSwitchButtonState()
    }
    
    private func refreshLensSelection() {
        let currentZoom = camera.currentZoomFactor
        guard let index = zoomOptions.enumerated().min(by: {
            abs($0.element - currentZoom) < abs($1.element - currentZoom)
        })?.offset else {
            lensControl.selectedSegmentIndex = UISegmentedControl.noSegment
            return
        }
        lensControl.selectedSegmentIndex = index
    }
    
    private func refreshStatus() {
        let positionText: String
        switch camera.currentCameraPosition {
        case .front:
            positionText = "前置"
        case .back:
            positionText = "后置"
        default:
            positionText = "未知"
        }
        statusLabel.text = "当前摄像头：\(positionText)"
        lensStatusLabel.text = "当前倍率：\(String(format: "%.1fx", camera.currentZoomFactor))"
    }
    
    private func refreshSwitchButtonState() {
        guard configuration.showSwitchButton else { return }
        let enabled = camera.canSwitchCamera()
        switchButton.isEnabled = enabled
        switchButton.alpha = enabled ? 1.0 : 0.4
    }
    
    @objc
    private func didTapLensControl() {
        guard lensControl.selectedSegmentIndex >= 0, lensControl.selectedSegmentIndex < zoomOptions.count else {
            return
        }
        let targetZoom = zoomOptions[lensControl.selectedSegmentIndex]
        selectionFeedback.selectionChanged()
        animateQuickSelectionFeedback()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            if abs(targetZoom - 0.5) < 0.05 {
                _ = self.camera.switchLens(to: .ultraWide)
            }
            else if abs(targetZoom - 1.0) < 0.05 {
                _ = self.camera.switchLens(to: .wide)
            }
            else if abs(targetZoom - 2.0) < 0.05 {
                _ = self.camera.switchLens(to: .telephoto)
            }
            else {
                self.camera.setZoomFactor(targetZoom, rampDuration: 0.10)
            }
        }
    }
    
    private func snapZoomIfNeeded(value: CGFloat) {
        guard !zoomOptions.isEmpty else { return }
        
        let current = value
        guard let nearest = zoomOptions.min(by: { abs($0 - current) < abs($1 - current) }) else {
            return
        }
        guard abs(nearest - current) <= 0.15 else { return }
        
        zoomDial.setValue(nearest, animated: true, notify: false)
        selectionFeedback.selectionChanged()
        camera.setZoomFactor(nearest, rampDuration: 0.08)
    }
    
    @objc
    private func didTapSwitchButton() {
        guard !isSwitchingCamera else { return }
        isSwitchingCamera = true
        setLoading(true)
        beginCameraSwitchTransition()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.camera.switchCamera()
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isAwaitingFirstFrameAfterSwitch = true
                    UIView.animate(withDuration: 0.3) {
                        self.switchButton.transform = self.switchButton.transform.rotated(by: .pi)
                    }
                    self.refreshLensOptions()
                    self.refreshStatus()
                    self.finishTransitionAfterTimeout()
                    self.selectionFeedback.prepare()
                    self.impactFeedback.prepare()
                    
                case .failure:
                    self.finishCameraSwitchTransition()
                    self.refreshLensSelection()
                    self.setLoading(false)
                }
                self.isSwitchingCamera = false
            }
        }
    }
    
    private func beginCameraSwitchTransition() {
        guard cameraView.bounds.width > 0, cameraView.bounds.height > 0 else { return }
        
        let token = UUID()
        switchTransitionToken = token
        
        let renderer = UIGraphicsImageRenderer(bounds: cameraView.bounds)
        let image = renderer.image { _ in
            cameraView.drawHierarchy(in: cameraView.bounds, afterScreenUpdates: false)
        }
        
        transitionSnapshotView.image = image
        transitionSnapshotView.isHidden = false
        transitionSnapshotView.alpha = 1
        transitionSnapshotView.transform = .identity
        
        UIView.animate(withDuration: 0.18) {
            self.transitionSnapshotView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.transitionSnapshotView.alpha = 0.92
        }
    }
    
    private func finishTransitionAfterTimeout() {
        let token = switchTransitionToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            guard self.switchTransitionToken == token else { return }
            guard self.isAwaitingFirstFrameAfterSwitch else { return }
            self.finishCameraSwitchTransition()
            self.isAwaitingFirstFrameAfterSwitch = false
            self.setLoading(false)
        }
    }
    
    private func handleCameraFrameRendered() {
        guard isAwaitingFirstFrameAfterSwitch else { return }
        isAwaitingFirstFrameAfterSwitch = false
        finishCameraSwitchTransition()
        setLoading(false)
    }
    
    private func finishCameraSwitchTransition() {
        let token = switchTransitionToken
        UIView.animate(withDuration: 0.22, animations: {
            self.transitionSnapshotView.alpha = 0
            self.transitionSnapshotView.transform = .identity
        }, completion: { _ in
            guard self.switchTransitionToken == token else { return }
            self.transitionSnapshotView.isHidden = true
            self.transitionSnapshotView.image = nil
            self.switchTransitionToken = nil
        })
    }
    
    private func configureDial(minZoom: CGFloat, maxZoom: CGFloat) {
        let hasUltraPreset = camera.getAvailableZoomPresets().contains(where: { abs($0 - 0.5) < 0.05 })
        let clampedMin = hasUltraPreset ? 0.5 : minZoom
        let clampedMax = max(clampedMin, min(10.0, maxZoom))
        zoomDial.minValue = clampedMin
        zoomDial.maxValue = clampedMax
        updateDialValue(camera.currentZoomFactor)
    }
    
    private func updateDialValue(_ zoom: CGFloat) {
        guard !zoomDial.isInteracting else { return }
        let clamped = max(zoomDial.minValue, min(zoom, zoomDial.maxValue))
        zoomDial.setValue(clamped, animated: false, notify: false)
    }
    
    private func zoomLabel(_ zoom: CGFloat) -> String {
        String(format: "%.1fx", zoom)
    }
    
    private func animateQuickSelectionFeedback() {
        UIView.animate(withDuration: 0.08, animations: {
            self.lensControl.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) {
                self.lensControl.transform = .identity
            }
        })
    }
    
    private func setLoading(_ loading: Bool) {
        lensControl.isEnabled = !loading
        zoomDial.isUserInteractionEnabled = configuration.showZoomSlider && !loading
        zoomDial.alpha = configuration.showZoomSlider ? 1.0 : 0.0
        switchButton.isEnabled = configuration.showSwitchButton && !loading && camera.canSwitchCamera()
        loading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }
}

public struct CMCameraCaptureView: UIViewControllerRepresentable {
    @ObservedObject private var camera: CMCamera
    private let configuration: CMCameraCaptureConfiguration
    
    public init(
        camera: CMCamera = CMCamera(),
        configuration: CMCameraCaptureConfiguration = .default
    ) {
        _camera = ObservedObject(wrappedValue: camera)
        self.configuration = configuration
    }
    
    public func makeUIViewController(context: Context) -> CMCameraCaptureViewController {
        CMCameraCaptureViewController(camera: camera, configuration: configuration)
    }
    
    public func updateUIViewController(_ uiViewController: CMCameraCaptureViewController, context: Context) {}
}

#Preview {
    CMCameraCaptureView()
}
