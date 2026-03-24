import UIKit
import Vision
import CoreImage

// MARK: - 主体提取管理器
@available(iOS 17.0, *)
class SubjectLifter {
    
    static let shared = SubjectLifter()
    
    /// 从图片中提取所有主体
    func extractSubject(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // 提取所有检测到的主体（index 0 是背景，1+ 是各个主体）
                let allInstances = result.allInstances
                guard allInstances.count > 1 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // ✅ 修正：直接使用 allInstances（已经是 IndexSet），排除背景 0
                var subjectIndices = allInstances
                subjectIndices.remove(0) // 移除背景
                
                let maskPixelBuffer = try result.generateScaledMaskForImage(
                    forInstances: subjectIndices,
                    from: handler
                )
                
                let maskedImage = self.applyMask(maskPixelBuffer, to: image)
                
                DispatchQueue.main.async {
                    completion(maskedImage)
                }
                
            } catch {
                print("Vision 请求失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// 提取点击位置的主体
    func extractSingleSubject(from image: UIImage, at point: CGPoint, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let allInstances = result.allInstances
                
                // ✅ 修正：获取点击位置对应的实例索引
                let targetIndex = self.findInstanceIndex(at: point, observation: result, imageSize: image.size, allInstances: allInstances)
                
                guard targetIndex > 0 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // ✅ 修正：创建只包含单个索引的 IndexSet
                var singleIndexSet = IndexSet()
                singleIndexSet.insert(targetIndex)
                
                let maskPixelBuffer = try result.generateScaledMaskForImage(
                    forInstances: singleIndexSet,
                    from: handler
                )
                
                let maskedImage = self.applyMask(maskPixelBuffer, to: image)
                
                DispatchQueue.main.async {
                    completion(maskedImage)
                }
                
            } catch {
                print("提取失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 通过分析 mask 数据查找点击位置对应的实例索引
    private func findInstanceIndex(at point: CGPoint, observation: VNInstanceMaskObservation, imageSize: CGSize, allInstances: IndexSet) -> Int {
        // 归一化坐标转像素坐标（Vision 使用左下角原点）
        let pixelX = Int(point.x * imageSize.width)
        let pixelY = Int((1.0 - point.y) * imageSize.height)
        
        // 获取原始 mask 的尺寸
        let maskPixelBuffer = observation.instanceMask
        let maskWidth = CVPixelBufferGetWidth(maskPixelBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskPixelBuffer)
        
        // 将点击坐标映射到 mask 坐标系
        let maskX = Int(Double(pixelX) / imageSize.width * Double(maskWidth))
        let maskY = Int(Double(pixelY) / imageSize.height * Double(maskHeight))
        
        // 锁定 pixel buffer
        CVPixelBufferLockBaseAddress(maskPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskPixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(maskPixelBuffer) else {
            // ✅ 修正：使用 first(where:) 获取第一个大于0的元素
            return allInstances.first(where: { $0 > 0 }) ?? 0
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskPixelBuffer)
        
        // 确保坐标在有效范围内
        let clampedX = max(0, min(maskX, maskWidth - 1))
        let clampedY = max(0, min(maskY, maskHeight - 1))
        
        // 读取像素值（32位整数）
        let pixelData = baseAddress.advanced(by: clampedY * bytesPerRow + clampedX * 4)
        let instanceIndex = pixelData.load(as: UInt32.self)
        
        // 如果点击的是背景(0)，返回第一个前景主体
        if instanceIndex == 0 {
            // ✅ 修正：使用 first(where:) 获取第一个大于0的元素
            return allInstances.first(where: { $0 > 0 }) ?? 0
        }
        
        return Int(instanceIndex)
    }
    
    /// 应用遮罩到图片
    private func applyMask(_ maskBuffer: CVPixelBuffer, to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        
        // 创建 CIImage
        var maskCIImage = CIImage(cvPixelBuffer: maskBuffer)
        
        // 调整遮罩大小以匹配原图
        let scaleX = CGFloat(cgImage.width) / CGFloat(width)
        let scaleY = CGFloat(cgImage.height) / CGFloat(height)
        maskCIImage = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 原图
        let inputCIImage = CIImage(cgImage: cgImage)
        
        // 使用 CIFilter 合成
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else { return nil }
        
        // 创建透明背景
        let context = CIContext(options: nil)
        guard let cgOutputImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgOutputImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
