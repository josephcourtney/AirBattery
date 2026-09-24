import AppKit

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func pasteFromClipboard() -> String? {
    if let content = NSPasteboard.general.string(forType: .string) { return content }
    return nil
}
