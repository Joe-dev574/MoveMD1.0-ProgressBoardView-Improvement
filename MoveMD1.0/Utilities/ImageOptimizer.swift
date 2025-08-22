
import UIKit
import AVFoundation // For AVMakeRect

struct ImageOptimizer {

    static func optimize(imageData: Data, targetSize: CGSize = CGSize(width: 1024, height: 1024), compressionQuality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: imageData) else {
            print("ImageOptimizer: Could not create UIImage from data.")
            return nil // Or return original data if optimization fails
        }

        // Calculate the new rect to maintain aspect ratio
        let aspectFillRect = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(origin: .zero, size: targetSize))
        let newSize = aspectFillRect.size

        // Check if resizing is even necessary (if image is already smaller)
        if image.size.width <= newSize.width && image.size.height <= newSize.height {
            // If smaller, just compress without resizing further
            print("ImageOptimizer: Image is smaller than or equal to target, only compressing.")
            return image.jpegData(compressionQuality: compressionQuality)
        }
        
        // Resize
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        print("ImageOptimizer: Resized image from \(image.size) to \(resizedImage.size). Compressing...")
        // Compress
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
