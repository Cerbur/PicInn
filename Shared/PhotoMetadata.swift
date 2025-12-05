import Foundation
import ImageIO

struct PhotoMetadata: Equatable {
    var iso: String = "-"
    var focalLength: String = "-"
    var shutterSpeed: String = "-"
    var aperture: String = "-"
    var make: String = "-"
    var model: String = "-"

    var cameraBrandLabel: String {
        if make.isEmpty || make == "-" { return "Unknown" }
        return make
    }

    static func from(properties: [AnyHashable: Any]) -> PhotoMetadata {
        var result = PhotoMetadata()

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [AnyHashable: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                result.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                result.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [AnyHashable: Any] {
            if let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first {
                result.iso = "ISO\(iso.intValue)"
            }
            if let fl = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber {
                result.focalLength = "\(fl.intValue)mm"
            }
            if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                result.aperture = "f/\(String(format: "%.1f", fNumber.doubleValue))"
            }
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber, exposureTime.doubleValue > 0 {
                if exposureTime.doubleValue < 1 {
                    let denominator = Int(round(1 / exposureTime.doubleValue))
                    result.shutterSpeed = "1/\(denominator)"
                } else {
                    result.shutterSpeed = String(format: "%.1fs", exposureTime.doubleValue)
                }
            }
        }

        return result
    }
}

