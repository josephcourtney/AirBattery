import Foundation

struct btAlert: Codable, Equatable {
    let name: String
    let full: Int
    let fullOn: Bool
    let fullSound: Bool
    let low: Int
    let lowOn: Bool
    let lowSound: Bool
}
