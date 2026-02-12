//
//  CMCameraPreviewDemo.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI
import UIKit
import Combine

public final class CMCameraPreviewDemoViewController: UIViewController {
    private let camera: CMCamera
    private let cameraView: CMCameraView
    
    private let statusLabel = UILabel()
    private let lensStatusLabel = UILabel()
    private let lensControl = UISegmentedControl(items: [])
    private let switchButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let transitionSnapshotView = UIImageView()
    
    private var lensOptions: [LensType] = []
    private var cancellables: Set<AnyCancellable> = []
    private var isSwitchingCamera = false
    private var isAwaitingFirstFrameAfterSwitch = false
    private var switchTransitionToken: UUID?
    
    public init(camera: CMCamera = CMCamera()) {
        self.camera = camera
        self.cameraView = CMCameraView(camera: camera)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        let camera = CMCamera()
        self.camera = camera
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
        
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        switchButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera", withConfiguration: config), for: .normal)
        switchButton.tintColor = .white
        switchButton.addTarget(self, action: #selector(didTapSwitchButton), for: .touchUpInside)
        
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
            cameraView.bottomAnchor.constraint(lessThanOrEqualTo: lensControl.topAnchor, constant: -16),
            
            switchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            switchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 68),
            switchButton.heightAnchor.constraint(equalToConstant: 68),
            lensControl.bottomAnchor.constraint(lessThanOrEqualTo: switchButton.topAnchor, constant: -16),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: lensControl.centerYAnchor)
        ])
        
        cameraView.onFrameRendered = { [weak self] in
            self?.handleCameraFrameRendered()
        }
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
        let lenses = camera.getAvailableLenses()
        if lenses == lensOptions {
            refreshLensSelection()
            refreshSwitchButtonState()
            return
        }
        
        lensOptions = lenses
        lensControl.removeAllSegments()
        for (index, lens) in lenses.enumerated() {
            lensControl.insertSegment(withTitle: lens.displayName, at: index, animated: false)
        }
        
        lensControl.isEnabled = !lenses.isEmpty
        refreshLensSelection()
        refreshSwitchButtonState()
    }
    
    private func refreshLensSelection() {
        guard let index = lensOptions.firstIndex(of: camera.currentLens) else {
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
        lensStatusLabel.text = "当前镜头：\(camera.currentLens.statusName)"
    }
    
    private func refreshSwitchButtonState() {
        let enabled = camera.canSwitchCamera()
        switchButton.isEnabled = enabled
        switchButton.alpha = enabled ? 1.0 : 0.4
    }
    
    @objc
    private func didTapLensControl() {
        guard lensControl.selectedSegmentIndex >= 0, lensControl.selectedSegmentIndex < lensOptions.count else {
            return
        }
        let targetLens = lensOptions[lensControl.selectedSegmentIndex]
        
        setLoading(true)
        _ = camera.switchLens(to: targetLens)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.setLoading(false)
        }
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
    
    private func setLoading(_ loading: Bool) {
        lensControl.isEnabled = !loading
        switchButton.isEnabled = !loading && camera.canSwitchCamera()
        loading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    }
}

public struct CMCameraPreviewDemo: UIViewControllerRepresentable {
    @ObservedObject private var camera: CMCamera
    
    public init(camera: CMCamera = CMCamera()) {
        _camera = ObservedObject(wrappedValue: camera)
    }
    
    public func makeUIViewController(context: Context) -> CMCameraPreviewDemoViewController {
        CMCameraPreviewDemoViewController(camera: camera)
    }
    
    public func updateUIViewController(_ uiViewController: CMCameraPreviewDemoViewController, context: Context) {}
}

#Preview {
    CMCameraPreviewDemo()
}
