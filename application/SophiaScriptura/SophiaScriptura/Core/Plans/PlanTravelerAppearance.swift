enum PlanTravelerBackdrop: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic, mountains, cloudy, library, sunny, moon, rainy

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .mountains: "Mountain terrain"
        case .cloudy: "Cloudy sky"
        case .library: "Library"
        case .sunny: "Sunny"
        case .moon: "Moonlit"
        case .rainy: "Rainy"
        }
    }

    func resolved(dark: Bool) -> Self {
        switch self {
        case .automatic: dark ? .moon : .sunny
        default: self
        }
    }
}

enum PlanTravelerEquipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case candle, lamp, armorOfGod

    var id: Self { self }

    var title: String {
        switch self {
        case .candle: "Candle"
        case .lamp: "Lamp"
        case .armorOfGod: "Armor of God"
        }
    }
}
