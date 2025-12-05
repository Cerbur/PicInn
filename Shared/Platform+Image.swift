import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS) || os(tvOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    var cgImageSafe: CGImage? {
        #if os(iOS) || os(tvOS)
        return cgImage
        #else
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
        #endif
    }
    
    var platformSize: CGSize {
        #if os(iOS) || os(tvOS)
        return self.size
        #else
        return self.size
        #endif
    }
    
    var aspectRatio: CGFloat {
        let size = platformSize
        guard size.height > 0 else { return 1.0 }
        return size.width / size.height
    }
}

