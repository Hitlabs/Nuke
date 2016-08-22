// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Performs image processing.
public protocol Processing: Equatable {
    associatedtype Object

    /// Returns processed image.
    func process(_ object: Object) -> Object?
}

/// Composes multiple image processors.
public struct ProcessorComposition<T>: Processing {
    public typealias Object = T

    private let processors: [AnyProcessor<T>]
    
    /// Composes multiple image processors.
    public init(processors: [AnyProcessor<T>]) {
        self.processors = processors
    }
    
    /// Processes the given image by applying each processor in an order in
    /// which they were added. If one of the processors fails to produce
    /// an image the processing stops and `nil` is returned.
    public func process(_ input: T) -> T? {
        return processors.reduce(input as T!) { obj, processor in
            return autoreleasepool { obj != nil ? processor.process(obj!) : nil }
        }
    }

    /// Returns true if the underlying processors are pairwise-equivalent.
    public static func ==(lhs: ProcessorComposition, rhs: ProcessorComposition) -> Bool {
        return lhs.processors.elementsEqual(rhs.processors)
    }
}

/// Type-erased image processor.
public struct AnyProcessor<T>: Processing {
    public typealias Object = T
    private let _process: (T) -> T?
    private let _processor: Any
    private let _equals: (AnyProcessor) -> Bool

    public init<P: Processing>(_ processor: P) where P.Object == T {
        self._process = { processor.process($0) }
        self._processor = processor
        self._equals = { ($0._processor as? P) == processor }
    }

    public func process(_ obj: T) -> T? {
        return self._process(obj)
    }

    public static func ==(lhs: AnyProcessor, rhs: AnyProcessor) -> Bool {
        return lhs._equals(rhs)
    }
}

#if !os(macOS)

    import UIKit

    /// Decompresses and (optionally) scales input images.
    ///
    /// Images are decompressed and scaled in a single pass which improves
    /// performance and reduces memory usage.
    ///
    /// If the input image size is bigger then the `targetSize` the image is
    /// resized to either fit or fill the size (see `ContentMode` enum
    /// for more info). Image aspect ratio is always maintained.
    public struct Decompressor: Processing {
        public typealias Object = UIImage

        /// An option for how to resize the image to the target size.
        public enum ContentMode {
            /// Scales the image so that it completely fills the target size.
            /// Maintains image aspect ratio. Images are not clipped.
            case aspectFill
            
            /// Scales the image so that its larger dimension fits the target size.
            /// Maintains image aspect ratio.
            case aspectFit
        }
        
        /// Size to pass to disable resizing.
        public static let MaximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        private let targetSize: CGSize
        private let contentMode: ContentMode

        /// Initializes `Decompressor` with the given parameters.
        /// - parameter targetSize: Size in pixels. `MaximumSize` by default.
        /// - parameter contentMode: An option for how to resize the image
        /// to the target size. `.aspectFill` by default.
        public init(targetSize: CGSize = MaximumSize, contentMode: ContentMode = .aspectFill) {
            self.targetSize = targetSize
            self.contentMode = contentMode
        }
        
        /// Decompresses and scales the image.
        public func process(_ image: Image) -> Image? {
            return decompress(image, targetSize: targetSize, contentMode: contentMode)
        }
        
        /// Returns true if both have the same `targetSize` and `contentMode`.
        public static func ==(lhs: Decompressor, rhs: Decompressor) -> Bool {
            return lhs.targetSize == rhs.targetSize && lhs.contentMode == rhs.contentMode
        }
    }
    
    private func decompress(_ image: UIImage, targetSize: CGSize, contentMode: Decompressor.ContentMode) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let bitmapSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleHor = targetSize.width / bitmapSize.width
        let scaleVert = targetSize.height / bitmapSize.height
        let scale = contentMode == .aspectFill ? max(scaleHor, scaleVert) : min(scaleHor, scaleVert)
        return decompress(image, scale: CGFloat(min(scale, 1)))
    }
    
    private func decompress(_ image: UIImage, scale: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let size = CGSize(width: round(scale * CGFloat(cgImage.width)),
                          height: round(scale * CGFloat(cgImage.height)))
        
        // For more info see:
        // - Quartz 2D Programming Guide
        // - https://github.com/kean/Nuke/issues/35
        // - https://github.com/kean/Nuke/issues/57
        let alphaInfo: CGImageAlphaInfo = isOpaque(cgImage) ? .noneSkipLast : .premultipliedLast
        
        guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue) else {
            return image
        }
        ctx.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: size))
        guard let decompressed = ctx.makeImage() else { return image }
        return UIImage(cgImage: decompressed, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func isOpaque(_ image: CGImage) -> Bool {
        let alpha = image.alphaInfo
        return alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast
    }
#endif
