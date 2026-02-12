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
    
    private var lensOptions: [LensType] = []
    private var cancellables: Set<AnyCancellable> = []
    
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
        
        view.addSubview(cameraView)
        view.addSubview(statusLabel)
        view.addSubview(lensStatusLabel)
        view.addSubview(lensControl)
        view.addSubview(switchButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            lensStatusLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            lensStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            cameraView.topAnchor.constraint(equalTo: lensStatusLabel.bottomAnchor, constant: 10),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.heightAnchor.constraint(equalTo: cameraView.widthAnchor, multiplier: 16.0 / 9.0),
            
            lensControl.topAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: 16),
            lensControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            lensControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            lensControl.heightAnchor.constraint(equalToConstant: 36),
            
            switchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            switchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 68),
            switchButton.heightAnchor.constraint(equalToConstant: 68),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: lensControl.centerYAnchor)
        ])
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
        setLoading(true)
        
        let result = camera.switchCamera()
        switch result {
        case .success:
            UIView.transition(with: cameraView, duration: 0.3, options: [.transitionFlipFromLeft, .curveEaseInOut]) {
                self.cameraView.layoutIfNeeded()
            }
            UIView.animate(withDuration: 0.3) {
                self.switchButton.transform = self.switchButton.transform.rotated(by: .pi)
            }
            refreshLensOptions()
            refreshStatus()
            
        case .failure:
            refreshLensSelection()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.setLoading(false)
        }
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
