//
//  CMCamera.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import UIKit
import AVFoundation

public class CMCamera: NSObject, @unchecked Sendable, ObservableObject {
    let session: AVCaptureSession = AVCaptureSession()
    
    private let cameraDataQueue = DispatchQueue(label: "camera.data.queue")
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let sessionQueueKey = DispatchSpecificKey<UInt8>()
    
    private var photoCaptureHandlers: [UUID: CMCameraPhotoCaptureDelegate] = [:]
    
    var cameraFrameDataHandler: ((CMSampleBuffer) -> Void)?
    public var onError: ((String) -> Void)?
    
    @Published public var photoCaptureSettings: CMPhotoCaptureSettings = .default
    @Published public private(set) var currentCameraPosition: AVCaptureDevice.Position = .unspecified
    @Published public private(set) var currentLens: LensType = .wide
    @Published public private(set) var availableLenses: [LensType] = []
    @Published public private(set) var currentZoomFactor: CGFloat = 1.0
    @Published public private(set) var minZoomFactor: CGFloat = 1.0
    @Published public private(set) var maxZoomFactor: CGFloat = 1.0
    
    public override init() {
        super.init()
        sessionQueue.setSpecific(key: sessionQueueKey, value: 1)
        
        do {
            try runOnSessionQueue {
                try setupSession()
            }
            refreshCameraState()
        }
        catch {
            report(error)
        }
    }
    
    /// 启动Session
    public func start() {
        guard !session.isRunning else { return }
        runOnSessionQueueAsync { [weak self] in
            self?.session.startRunning()
        }
    }
    
    /// 停止Session
    public func stop() {
        guard session.isRunning else { return }
        runOnSessionQueueAsync { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    public func setFocus(_ point: CGPoint) {
        print("Comet Camera: set focus at:", point)
        guard let inputDevice = currentDevice() else { return }
        do {
            try inputDevice.lockForConfiguration()
            
            if inputDevice.isFocusPointOfInterestSupported {
                inputDevice.focusPointOfInterest = point
            }
            if inputDevice.isFocusModeSupported(.autoFocus) {
                inputDevice.focusMode = .autoFocus
            }
            
            if inputDevice.isExposurePointOfInterestSupported {
                inputDevice.exposurePointOfInterest = point
            }
            if inputDevice.isExposureModeSupported(.autoExpose) {
                inputDevice.exposureMode = .autoExpose
            }
            
            inputDevice.unlockForConfiguration()
        }
        catch {
            print("Comet Camera: set focus failed:", error.localizedDescription)
        }
    }
    
    public func setZoomFactor(_ factor: CGFloat, rampDuration: TimeInterval = 0.12) {
        print("Comet Camera: set zoom factor at:", factor)
        runOnSessionQueueAsync { [weak self] in
            guard let self, let device = self.currentDevice() else { return }
            do {
                try device.lockForConfiguration()
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = self.effectiveMaxZoomFactor(for: device)
                let clampFactor = max(minZoom, min(factor, maxZoom))
                
                let delta = abs(device.videoZoomFactor - clampFactor)
                let duration = max(0.04, rampDuration)
                let rampRate = Float(max(delta / duration, 6.0))
                device.ramp(toVideoZoomFactor: clampFactor, withRate: rampRate)
                
                device.unlockForConfiguration()
                DispatchQueue.main.async { [weak self] in
                    self?.currentZoomFactor = clampFactor
                    self?.currentLens = self?.resolveLensFromZoom(
                        zoom: clampFactor,
                        availableLenses: self?.availableLenses ?? []
                    ) ?? .wide
                }
            }
            catch {
                print("Comet Camera: set zoom factor failed:", error.localizedDescription)
            }
        }
    }
    
    public func getAvailableLenses() -> [LensType] {
        availableLenses
    }
    
    public func getAvailableZoomPresets() -> [CGFloat] {
        let zoomMin = minZoomFactor
        let zoomMax = maxZoomFactor
        
        var presets: [CGFloat] = []
        if currentCameraPosition == .back, availableLenses.contains(.ultraWide) {
            presets.append(0.5)
        }
        if zoomMin <= 1.0, zoomMax >= 1.0 {
            presets.append(1.0)
        }
        if currentCameraPosition == .back, zoomMax >= 2.0 {
            presets.append(2.0)
        }
        
        if presets.isEmpty {
            presets = [min(max(1.0, zoomMin), zoomMax)]
        }
        return presets
    }
    
    public func canSwitchCamera() -> Bool {
        isCameraPositionAvailable(.front) && isCameraPositionAvailable(.back)
    }
    
    @discardableResult
    public func switchCamera() -> Result<Void, CMCameraError> {
        let targetPosition: AVCaptureDevice.Position = currentCameraPosition == .front ? .back : .front
        guard isCameraPositionAvailable(targetPosition) else {
            let error = CMCameraError.cameraUnavailable(position: targetPosition)
            report(error)
            return .failure(error)
        }
        
        if targetPosition == .front {
            requestMicrophonePermissionIfNeeded()
        }
        
        let preferredLens: LensType = {
            let frontLenses = discoverLenses(at: .front)
            if targetPosition == .front, frontLenses.contains(.wide) {
                return .wide
            }
            return currentLens
        }()
        
        let result = switchInput(to: targetPosition, preferredLens: preferredLens)
        if case .success = result {
            refreshCameraState()
        }
        return result
    }
    
    @discardableResult
    public func switchLens(to lens: LensType) -> Result<Void, CMCameraError> {
        do {
            let switchedSmoothly = try runOnSessionQueue {
                guard let device = currentDevice() else {
                    throw CMCameraError.deviceUnavailable
                }
                let supported = buildAvailableLenses(position: device.position, device: device)
                guard supported.contains(lens) else {
                    throw CMCameraError.lensUnavailable(lens)
                }
                if lens == currentLens {
                    return true
                }
                
                guard device.position == .back, isVirtualMultiLensDevice(device) else {
                    return false
                }
                guard let targetZoom = targetZoomFactor(for: lens, device: device, supportedLenses: supported) else {
                    throw CMCameraError.lensUnavailable(lens)
                }
                
                try device.lockForConfiguration()
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = effectiveMaxZoomFactor(for: device)
                let clampedZoom = max(minZoom, min(targetZoom, maxZoom))
                let delta = abs(device.videoZoomFactor - clampedZoom)
                if delta > 0.01 {
                    let rampRate = Float(max(delta / 0.12, 6.0))
                    device.ramp(toVideoZoomFactor: clampedZoom, withRate: rampRate)
                }
                device.unlockForConfiguration()
                return true
            }
            
            if switchedSmoothly {
                DispatchQueue.main.async { [weak self] in
                    self?.currentLens = lens
                    if lens == .ultraWide {
                        self?.currentZoomFactor = 0.5
                    }
                    else if lens == .wide {
                        self?.currentZoomFactor = 1.0
                    }
                    else {
                        self?.currentZoomFactor = 2.0
                    }
                }
                return .success(())
            }
        }
        catch let error as CMCameraError {
            report(error)
            return .failure(error)
        }
        catch {
            let cameraError = CMCameraError.configurationFailed(error.localizedDescription)
            report(cameraError)
            return .failure(cameraError)
        }
        
        let result = switchInput(to: currentCameraPosition, preferredLens: lens)
        if case .success = result {
            refreshCameraState()
        }
        return result
    }
    
    /// 拍照
    public func takePhoto() async -> CMPhoto? {
        guard let photoOutput = session.outputs.first(where: { $0 is AVCapturePhotoOutput }) as? AVCapturePhotoOutput else { return nil }
        
        let setting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        setting.flashMode = photoCaptureSettings.flashMode
        setting.photoQualityPrioritization = .quality
        
        return await withCheckedContinuation { checkedContinuation in
            let photoCaptureDelegate = CMCameraPhotoCaptureDelegate { [weak self] id, sampleBuffer, error in
                let strongSelf = self
                strongSelf?.photoCaptureHandlers.removeValue(forKey: id)
                
                if let pixelBuffer = sampleBuffer {
                    let photo = CMPhoto(pixelBuffer: pixelBuffer)
                    checkedContinuation.resume(returning: photo)
                }
                else {
                    checkedContinuation.resume(returning: nil)
                }
            }
            photoCaptureHandlers[photoCaptureDelegate.id] = photoCaptureDelegate
            photoOutput.capturePhoto(with: setting, delegate: photoCaptureDelegate)
        }
    }
    
    private func setupSession() throws {
        try addInput(position: .back, preferredLens: .wide)
        
        addOutput()
        addPhotoCaptureOutput()
        
    }
    
    private func currentDevice() -> AVCaptureDevice? {
        guard let inputDevice = session.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        return inputDevice.device
    }
    
    private func addInput(position: AVCaptureDevice.Position, preferredLens: LensType) throws {
        guard let device = makeCaptureDevice(position: position, preferredLens: preferredLens) else {
            throw CMCameraError.cameraUnavailable(position: position)
        }
        
        do {
            session.beginConfiguration()
            for input in session.inputs {
                session.removeInput(input)
            }
            let cameraInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }
            session.commitConfiguration()
        }
        catch {
            throw CMCameraError.inputFailed(error.localizedDescription)
        }
    }
    
    private func switchInput(to position: AVCaptureDevice.Position, preferredLens: LensType) -> Result<Void, CMCameraError> {
        do {
            try runOnSessionQueue {
                guard let oldDevice = currentDevice() else {
                    throw CMCameraError.deviceUnavailable
                }
                let snapshot = readConfigurationSnapshot(from: oldDevice)
                
                guard let newDevice = makeCaptureDevice(position: position, preferredLens: preferredLens) else {
                    throw CMCameraError.cameraUnavailable(position: position)
                }
                
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                session.beginConfiguration()
                for input in session.inputs {
                    session.removeInput(input)
                }
                
                guard session.canAddInput(newInput) else {
                    session.commitConfiguration()
                    throw CMCameraError.configurationFailed("无法添加摄像头输入。")
                }
                session.addInput(newInput)
                session.commitConfiguration()
                
                applyConfigurationSnapshot(snapshot, to: newDevice)
            }
            return .success(())
        }
        catch let error as CMCameraError {
            report(error)
            return .failure(error)
        }
        catch {
            let cameraError = CMCameraError.configurationFailed(error.localizedDescription)
            report(cameraError)
            return .failure(cameraError)
        }
    }
    
    private func addOutput() {
        session.beginConfiguration()
        let cameraOutput = AVCaptureVideoDataOutput()
        cameraOutput.setSampleBufferDelegate(self, queue: cameraDataQueue)
        cameraOutput.alwaysDiscardsLateVideoFrames = true
        cameraOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(cameraOutput) {
            session.addOutput(cameraOutput)
        }
        
        if let connection = cameraOutput.connection(with: .video) {
            if #available(iOS 17, *) {
                if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
                
            }
            else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        session.commitConfiguration()
    }
    
    private func addPhotoCaptureOutput() {
        session.beginConfiguration()
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }
    
    private func refreshCameraState() {
        let snapshot: (AVCaptureDevice.Position, [LensType], LensType, CGFloat, CGFloat, CGFloat)? = try? runOnSessionQueue {
            guard let device = currentDevice() else { return nil }
            let position = device.position
            let lenses = buildAvailableLenses(position: position, device: device)
            let current = resolveCurrentLens(device: device, availableLenses: lenses)
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = effectiveMaxZoomFactor(for: device)
            let zoom = max(minZoom, min(device.videoZoomFactor, maxZoom))
            return (position, lenses, current, minZoom, maxZoom, zoom)
        }
        
        guard let snapshot else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentCameraPosition = snapshot.0
            self?.availableLenses = snapshot.1
            self?.currentLens = snapshot.2
            self?.minZoomFactor = snapshot.3
            self?.maxZoomFactor = snapshot.4
            self?.currentZoomFactor = snapshot.5
        }
    }
    
    private func makeCaptureDevice(position: AVCaptureDevice.Position, preferredLens: LensType) -> AVCaptureDevice? {
        if position == .back {
            let virtualTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera
            ]
            for type in virtualTypes {
                if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                    return device
                }
            }
        }
        
        let preferredType = deviceType(for: preferredLens)
        let fallbackTypes = preferredDeviceTypes(for: position)
            .filter { $0 != preferredType }
        let candidateTypes = [preferredType] + fallbackTypes
        
        for type in candidateTypes {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                return device
            }
        }
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredDeviceTypes(for: position),
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }
    
    private func preferredDeviceTypes(for position: AVCaptureDevice.Position) -> [AVCaptureDevice.DeviceType] {
        if position == .front {
            return [.builtInWideAngleCamera, .builtInTrueDepthCamera]
        }
        return [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
    }
    
    private func discoverLenses(at position: AVCaptureDevice.Position) -> [LensType] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: position
        )
        
        var result: [LensType] = []
        for lens in LensType.allCases {
            if discovery.devices.contains(where: { $0.deviceType == deviceType(for: lens) }) {
                result.append(lens)
            }
        }
        return result
    }
    
    private func buildAvailableLenses(position: AVCaptureDevice.Position, device: AVCaptureDevice) -> [LensType] {
        var result = discoverLenses(at: position)
        
        if !result.contains(.wide) {
            result.append(.wide)
        }
        
        if position == .back {
            if device.minAvailableVideoZoomFactor < 1.0, !result.contains(.ultraWide) {
                result.append(.ultraWide)
            }
            if effectiveMaxZoomFactor(for: device) >= 2.0, !result.contains(.telephoto) {
                result.append(.telephoto)
            }
        }
        
        return LensType.allCases.filter { result.contains($0) }
    }
    
    private func isCameraPositionAvailable(_ position: AVCaptureDevice.Position) -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredDeviceTypes(for: position),
            mediaType: .video,
            position: position
        )
        return !discovery.devices.isEmpty
    }
    
    private func deviceType(for lens: LensType) -> AVCaptureDevice.DeviceType {
        switch lens {
        case .ultraWide:
            return .builtInUltraWideCamera
        case .wide:
            return .builtInWideAngleCamera
        case .telephoto:
            return .builtInTelephotoCamera
        }
    }
    
    private func lensType(for deviceType: AVCaptureDevice.DeviceType) -> LensType {
        switch deviceType {
        case .builtInUltraWideCamera:
            return .ultraWide
        case .builtInTelephotoCamera:
            return .telephoto
        default:
            return .wide
        }
    }
    
    private func resolveCurrentLens(device: AVCaptureDevice, availableLenses: [LensType]) -> LensType {
        guard device.position == .back, isVirtualMultiLensDevice(device) else {
            return lensType(for: device.deviceType)
        }
        
        let zoomFactor = device.videoZoomFactor
        return resolveLensFromZoom(zoom: zoomFactor, availableLenses: availableLenses, device: device)
    }
    
    private func resolveLensFromZoom(zoom: CGFloat, availableLenses: [LensType], device: AVCaptureDevice? = nil) -> LensType {
        let zoomFactor = zoom
        let factors = device.map { sortedSwitchOverFactors(for: $0) } ?? []
        let hasUltra = availableLenses.contains(.ultraWide)
        let hasTele = availableLenses.contains(.telephoto)
        
        if hasUltra && hasTele {
            let ultraWideBoundary = factors.first ?? 1.0
            let teleBoundary = factors.count > 1 ? factors[1] : 2.0
            if zoomFactor < ultraWideBoundary {
                return .ultraWide
            }
            if zoomFactor >= teleBoundary {
                return .telephoto
            }
            return .wide
        }
        
        if hasUltra {
            let boundary = factors.first ?? 1.0
            return zoomFactor < boundary ? .ultraWide : .wide
        }
        
        if hasTele {
            return zoomFactor >= 2.0 ? .telephoto : .wide
        }
        
        return .wide
    }
    
    private func isVirtualMultiLensDevice(_ device: AVCaptureDevice) -> Bool {
        switch device.deviceType {
        case .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera:
            return true
        default:
            return false
        }
    }
    
    private func sortedSwitchOverFactors(for device: AVCaptureDevice) -> [CGFloat] {
        device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }
            .sorted()
    }
    
    private func targetZoomFactor(for lens: LensType, device: AVCaptureDevice, supportedLenses: [LensType]) -> CGFloat? {
        let factors = sortedSwitchOverFactors(for: device)
        let hasUltra = supportedLenses.contains(.ultraWide)
        let hasTele = supportedLenses.contains(.telephoto) || effectiveMaxZoomFactor(for: device) >= 2.0
        
        switch lens {
        case .ultraWide:
            return hasUltra ? device.minAvailableVideoZoomFactor : nil
            
        case .wide:
            if hasUltra {
                return factors.first ?? 1.0
            }
            return 1.0
            
        case .telephoto:
            guard hasTele else { return nil }
            if !supportedLenses.contains(.telephoto) {
                return 2.0
            }
            let boundary: CGFloat
            if hasUltra {
                boundary = factors.count > 1 ? factors[1] : max(2.0, (factors.first ?? 1.0) + 0.5)
            }
            else {
                boundary = factors.first ?? 2.0
            }
            return boundary + 0.15
        }
    }
    
    private struct DeviceConfigurationSnapshot {
        let focusMode: AVCaptureDevice.FocusMode?
        let focusPointOfInterest: CGPoint?
        let exposureMode: AVCaptureDevice.ExposureMode?
        let exposurePointOfInterest: CGPoint?
        let zoomFactor: CGFloat
    }
    
    private func readConfigurationSnapshot(from device: AVCaptureDevice) -> DeviceConfigurationSnapshot {
        DeviceConfigurationSnapshot(
            focusMode: device.isFocusModeSupported(device.focusMode) ? device.focusMode : nil,
            focusPointOfInterest: device.isFocusPointOfInterestSupported ? device.focusPointOfInterest : nil,
            exposureMode: device.isExposureModeSupported(device.exposureMode) ? device.exposureMode : nil,
            exposurePointOfInterest: device.isExposurePointOfInterestSupported ? device.exposurePointOfInterest : nil,
            zoomFactor: device.videoZoomFactor
        )
    }
    
    private func applyConfigurationSnapshot(_ snapshot: DeviceConfigurationSnapshot, to device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if let focusMode = snapshot.focusMode, device.isFocusModeSupported(focusMode) {
                device.focusMode = focusMode
            }
            if let focusPoint = snapshot.focusPointOfInterest, device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
            }
            if let exposureMode = snapshot.exposureMode, device.isExposureModeSupported(exposureMode) {
                device.exposureMode = exposureMode
            }
            if let exposurePoint = snapshot.exposurePointOfInterest, device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = exposurePoint
            }
            
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = effectiveMaxZoomFactor(for: device)
            let clampedZoom = min(max(snapshot.zoomFactor, minZoom), maxZoom)
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
        }
        catch {
            report(CMCameraError.configurationFailed(error.localizedDescription))
        }
    }
    
    private func requestMicrophonePermissionIfNeeded() {
        let permission = AVAudioSession.sharedInstance().recordPermission
        guard permission == .undetermined else {
            if permission == .denied {
                report(CMCameraError.permissionDenied("麦克风权限被拒绝，若需要录音请在系统设置中开启。"))
            }
            return
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard !granted else { return }
            self?.report(CMCameraError.permissionDenied("麦克风权限被拒绝，若需要录音请在系统设置中开启。"))
        }
    }
    
    private func runOnSessionQueue<T>(_ operation: () throws -> T) throws -> T {
        if DispatchQueue.getSpecific(key: sessionQueueKey) != nil {
            return try operation()
        }
        return try sessionQueue.sync {
            try operation()
        }
    }
    
    private func runOnSessionQueueAsync(_ operation: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: sessionQueueKey) != nil {
            operation()
            return
        }
        sessionQueue.async(execute: operation)
    }
    
    private func effectiveMaxZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        min(10.0, min(device.activeFormat.videoMaxZoomFactor, device.maxAvailableVideoZoomFactor))
    }
    
    private func report(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Comet Camera error:", message)
        DispatchQueue.main.async { [weak self] in
            self?.onError?(message)
        }
    }
    
}

extension CMCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        cameraFrameDataHandler?(sampleBuffer)
    }
}
