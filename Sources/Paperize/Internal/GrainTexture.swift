import UIKit

/// A small, tileable, deterministic paper-grain texture. It's generated once and shared.
enum GrainTexture {

    /// A light gray noise tile, meant to be multiplied over content.
    static let image: UIImage = make()

    static func make(size: Int = 96, seed: UInt64 = 0x5EED_FACE_CAFE_F00D) -> UIImage {
        var random = SplitMix64(state: seed)
        var pixels = [UInt8](repeating: 255, count: size * size)
        for index in pixels.indices {
            // Mostly near-white with sparse darker fibers. Multiplying by this only darkens slightly.
            let base = 214 + Int(random.next() % 42)          // 214...255
            let fiber = random.next() % 97 == 0 ? 40 : 0      // ~1% darker specks
            pixels[index] = UInt8(max(0, base - fiber))
        }

        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let cgImage = CGImage(
                width: size,
                height: size,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            return UIImage()
        }
        // Scale 2 keeps the grain fine: one texel is half a point.
        return UIImage(cgImage: cgImage, scale: 2, orientation: .up)
    }
}

/// A tiny, fast, seedable PRNG, so the texture is identical on every launch.
struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
