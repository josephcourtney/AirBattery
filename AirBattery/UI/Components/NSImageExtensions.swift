import AppKit

extension NSImage {
    func resized(to maxSize: NSSize) -> NSImage {
        let aspectWidth = maxSize.width / size.width
        let aspectHeight = maxSize.height / size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        let newSize = NSSize(
            width: size.width * aspectRatio,
            height: size.height * aspectRatio
        )

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .sourceOver,
            fraction: 1
        )
        newImage.unlockFocus()
        return newImage
    }
}
