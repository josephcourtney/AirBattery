import Foundation

package func getFiles(withExtension fileExtension: String, in directory: URL) -> [URL] {
    do {
        let filesAndDirectories = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        return filesAndDirectories.filter { $0.pathExtension == fileExtension }
    } catch {
        print("Failed to get contents of directory: \(error)")
        return []
    }
}
