import UIKit

enum ImageStoreError: LocalizedError {
    case encodeFailed

    var errorDescription: String? {
        "Couldn't save that photo."
    }
}

struct ImageStore {
    var directory: URL

    func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @discardableResult
    func saveJPEG(_ image: UIImage, name: String, maxPixel: CGFloat = 1600, quality: CGFloat = 0.82) throws -> String {
        try prepare()
        let resized = image.scaledToFit(maxPixel: maxPixel)
        guard let data = resized.jpegData(quality: quality) else {
            throw ImageStoreError.encodeFailed
        }
        let filename = name.hasSuffix(".jpg") ? name : "\(name).jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    func saveData(_ data: Data, filename: String) throws {
        try prepare()
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    func load(_ filename: String) -> UIImage? {
        guard let data = data(for: filename) else { return nil }
        return UIImage(data: data)
    }

    func data(for filename: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(filename))
    }

    func remove(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    func widgetJPEG(for filename: String) -> Data? {
        guard let image = load(filename) else { return nil }
        return image.scaledToFit(maxPixel: 800).jpegData(quality: 0.72)
    }
}

extension UIImage {
    func scaledToFit(maxPixel: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxPixel, largest > 0 else { return self }
        let scale = maxPixel / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
