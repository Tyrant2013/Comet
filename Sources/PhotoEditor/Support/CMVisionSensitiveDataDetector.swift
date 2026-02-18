import Foundation
import Vision
import CoreImage
import CoreGraphics

@available(iOS 13.0, macOS 10.15, *)
public final class CMVisionSensitiveDataDetector: CMSensitiveDataDetecting {
    private let matcher: CMSensitiveTextPatternMatcher

    public init(matcher: CMSensitiveTextPatternMatcher = CMSensitiveTextPatternMatcher()) {
        self.matcher = matcher
    }

    public func detectSensitiveData(in image: CIImage) throws -> [CMSensitiveDataMatch] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let extent = image.extent

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string
            guard matcher.containsSensitiveText(text) else { return nil }

            let rect = VNImageRectForNormalizedRect(observation.boundingBox, Int(extent.width), Int(extent.height))
            return CMSensitiveDataMatch(bounds: rect, text: text)
        }
    }
}
