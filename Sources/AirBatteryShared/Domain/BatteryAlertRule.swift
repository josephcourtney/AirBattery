import Foundation

package struct btAlert: Codable, Equatable {
    package let name: String
    package let full: Int
    package let fullOn: Bool
    package let fullSound: Bool
    package let low: Int
    package let lowOn: Bool
    package let lowSound: Bool

    package init(
        name: String,
        full: Int,
        fullOn: Bool,
        fullSound: Bool,
        low: Int,
        lowOn: Bool,
        lowSound: Bool
    ) {
        self.name = name
        self.full = full
        self.fullOn = fullOn
        self.fullSound = fullSound
        self.low = low
        self.lowOn = lowOn
        self.lowSound = lowSound
    }
}
