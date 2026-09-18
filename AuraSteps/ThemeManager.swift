import SwiftUI
import Combine

/// Presets de colores de acento deportivos.
public enum AccentColorPreset: String, CaseIterable, Identifiable {
    case neonLime = "Lima Neón"
    case electricBlue = "Azul Eléctrico"
    case vividViolet = "Violeta"
    case neonOrange = "Naranja Neón"
    case hotPink = "Rosa Neón"
    case cyan = "Cian"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .neonLime: return Color(red: 163/255, green: 230/255, blue: 53/255) // #A3E635
        case .electricBlue: return Color(red: 59/255, green: 130/255, blue: 246/255) // #3B82F6
        case .vividViolet: return Color(red: 139/255, green: 92/255, blue: 246/255) // #8B5CF6
        case .neonOrange: return Color(red: 249/255, green: 115/255, blue: 22/255) // #F97316
        case .hotPink: return Color(red: 236/255, green: 72/255, blue: 153/255) // #EC4899
        case .cyan: return Color(red: 6/255, green: 182/255, blue: 212/255) // #06B6D4
        }
    }
}

/// Presets de colores de fondo estilo Dark Mode.
public enum BackgroundColorPreset: String, CaseIterable, Identifiable {
    case deepNight = "Noche Profunda"
    case pureBlack = "Negro Puro"
    case carbon = "Carbón"
    case darkOcean = "Océano Oscuro"
    
    public var id: String { rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .deepNight: return Color(red: 9/255, green: 9/255, blue: 11/255) // #09090B
        case .pureBlack: return Color(red: 0, green: 0, blue: 0) // #000000
        case .carbon: return Color(red: 18/255, green: 19/255, blue: 26/255) // #12131A
        case .darkOcean: return Color(red: 11/255, green: 19/255, blue: 43/255) // #0B132B
        }
    }
    
    public var cardColor: Color {
        switch self {
        case .deepNight: return Color(red: 18/255, green: 18/255, blue: 22/255)
        case .pureBlack: return Color(red: 20/255, green: 20/255, blue: 20/255)
        case .carbon: return Color(red: 28/255, green: 30/255, blue: 40/255)
        case .darkOcean: return Color(red: 20/255, green: 32/255, blue: 60/255)
        }
    }
}

/// Presets de animaciones de fondo interactivas.
public enum BackgroundAnimationPreset: String, CaseIterable, Identifiable {
    case none = "Ninguna"
    case bubbles = "Burbujas"
    case hexagons = "Hexágonos"
    case aurora = "Aurora"
    case stardust = "Polvo Estelar"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .bubbles: return "drop.circle.fill"
        case .hexagons: return "hexagon.fill"
        case .aurora: return "waveform.path.ecg"
        case .stardust: return "sparkles"
        }
    }
}

/// Gestor global del tema visual dinámico de AuraSteps (iOS 16+).
@MainActor
public final class ThemeManager: ObservableObject {
    @Published public var accentPreset: AccentColorPreset {
        didSet {
            UserDefaults.standard.set(accentPreset.rawValue, forKey: "user_accent_preset")
            objectWillChange.send()
        }
    }
    
    @Published public var backgroundPreset: BackgroundColorPreset {
        didSet {
            UserDefaults.standard.set(backgroundPreset.rawValue, forKey: "user_background_preset")
            objectWillChange.send()
        }
    }
    
    @Published public var backgroundAnimation: BackgroundAnimationPreset {
        didSet {
            UserDefaults.standard.set(backgroundAnimation.rawValue, forKey: "user_background_animation")
            objectWillChange.send()
        }
    }
    
    public var themeId: String {
        "\(accentPreset.rawValue)_\(backgroundPreset.rawValue)_\(backgroundAnimation.rawValue)"
    }
    
    public init() {
        let savedAccent = UserDefaults.standard.string(forKey: "user_accent_preset") ?? AccentColorPreset.neonLime.rawValue
        let savedBg = UserDefaults.standard.string(forKey: "user_background_preset") ?? BackgroundColorPreset.deepNight.rawValue
        let savedAnim = UserDefaults.standard.string(forKey: "user_background_animation") ?? BackgroundAnimationPreset.none.rawValue
        
        self.accentPreset = AccentColorPreset(rawValue: savedAccent) ?? .neonLime
        self.backgroundPreset = BackgroundColorPreset(rawValue: savedBg) ?? .deepNight
        self.backgroundAnimation = BackgroundAnimationPreset(rawValue: savedAnim) ?? .none
    }
    
    public var accentColor: Color { accentPreset.color }
    public var backgroundColor: Color { backgroundPreset.backgroundColor }
    public var cardColor: Color { backgroundPreset.cardColor }
    
    public func resetToDefaults() {
        self.accentPreset = .neonLime
        self.backgroundPreset = .deepNight
        self.backgroundAnimation = .none
    }
}

// MARK: - Extensión Color con Hexadecimal

extension Color {
    public init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

