import UIKit

/// Drawn stand-ins for the practice partner and for the simulator, where there
/// may be no camera. These are flat illustrations, not photos of anyone.
enum SampleArtwork {
    static func backScene(seed: UInt64) -> UIImage {
        render(size: CGSize(width: 900, height: 1200)) { context, size in
            let hue = CGFloat(seed % 360) / 360
            let top = UIColor(hue: hue, saturation: 0.38, brightness: 0.96, alpha: 1)
            let bottom = UIColor(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.28, brightness: 0.62, alpha: 1)
            drawGradient(in: context.cgContext, size: size, top: top, bottom: bottom, height: size.height * 0.7)
            let ground = UIColor(hue: (hue + 0.32).truncatingRemainder(dividingBy: 1), saturation: 0.28, brightness: 0.38, alpha: 1)
            ground.setFill()
            context.fill(CGRect(x: 0, y: size.height * 0.68, width: size.width, height: size.height * 0.32))

            UIColor(hue: 0.11, saturation: 0.28, brightness: 1, alpha: 1).setFill()
            let sun = CGRect(x: size.width * 0.66, y: size.height * 0.14, width: 150, height: 150)
            context.cgContext.fillEllipse(in: sun)

            let blockCount = 3 + Int(seed % 3)
            for index in 0..<blockCount {
                let width = 70 + CGFloat((seed >> (index * 5)) % 80)
                let height = 90 + CGFloat((seed >> (index * 3)) % 140)
                let x = 50 + CGFloat(index) * 150
                let y = size.height * 0.68 - height + 8
                let color = UIColor(white: 0.93 - CGFloat(index) * 0.08, alpha: 1)
                color.setFill()
                context.fill(CGRect(x: x, y: y, width: width, height: height))
            }
        }
    }

    static func portrait(seed: UInt64) -> UIImage {
        render(size: CGSize(width: 900, height: 1200)) { context, size in
            let hue = CGFloat((seed / 7) % 360) / 360
            UIColor(hue: hue, saturation: 0.22, brightness: 0.93, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let face = CGRect(x: size.width * 0.22, y: size.height * 0.22, width: size.width * 0.56, height: size.width * 0.62)
            UIColor(hue: 0.07, saturation: 0.35, brightness: 0.86, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: face)

            let eyeY = face.midY - 10
            UIColor(white: 0.15, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: face.midX - 70, y: eyeY, width: 22, height: 22))
            context.cgContext.fillEllipse(in: CGRect(x: face.midX + 48, y: eyeY, width: 22, height: 22))

            UIColor(hue: 0.02, saturation: 0.45, brightness: 0.55, alpha: 1).setStroke()
            let smile = UIBezierPath()
            smile.addArc(
                withCenter: CGPoint(x: face.midX, y: face.midY + 40),
                radius: 36,
                startAngle: 0.2,
                endAngle: .pi - 0.2,
                clockwise: true
            )
            smile.lineWidth = 6
            smile.stroke()
        }
    }

    static func standInPair(seed: UInt64) -> (back: UIImage, front: UIImage) {
        (backScene(seed: seed), portrait(seed: seed &+ 19))
    }

    private static func render(
        size: CGSize,
        draw: (UIGraphicsImageRendererContext, CGSize) -> Void
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context, size)
        }
    }

    private static func drawGradient(
        in context: CGContext,
        size: CGSize,
        top: UIColor,
        bottom: UIColor,
        height: CGFloat
    ) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: 0, y: height),
            options: [.drawsAfterEndLocation]
        )
    }
}
