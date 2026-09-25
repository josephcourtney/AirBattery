import Foundation

func getFiles(withExtension fileExtension: String, in directory: URL) -> [URL] {
    do {
        let filesAndDirectories = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
        let filteredFiles = filesAndDirectories.filter { $0.pathExtension == fileExtension }
        return filteredFiles
    } catch {
        print("Failed to get contents of directory: \(error)")
        return []
    }
}
