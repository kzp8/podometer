import SwiftUI

// MARK: - Contenedor Principal de Fondo Dinámico

/// Vista de fondo global que combina el color del tema con la animación de fondo seleccionada.
@MainActor
public struct AppBackgroundView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        ZStack {
            themeManager.backgroundColor
            
            Group {
                switch themeManager.backgroundAnimation {
                case .none:
                    Color.clear
                case .bubbles:
                    BubblesAnimationView()
                case .hexagons:
                    HexagonsAnimationView()
                case .aurora:
                    AuroraAnimationView()
                case .stardust:
                    StardustAnimationView()
                }
            }
            .animation(.easeInOut(duration: 0.45), value: themeManager.backgroundAnimation)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 1. Animación de Burbujas Flotantes (TimelineView + Canvas sin glitches)

@MainActor
public struct BubblesAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public struct BubbleData: Identifiable, Sendable {
        public let id: Int
        public let xRatio: CGFloat
        public let size: CGFloat
        public let speed: Double
        public let swaySpeed: Double
        public let swayAmp: CGFloat
        public let phase: Double
        public let opacity: Double
    }
    
    // 16 burbujas distribuidas armónicamente
    private let bubbles: [BubbleData] = (0..<16).map { i in
        let x = CGFloat((i * 37 + 13) % 100) / 100.0
        let s = CGFloat(24 + ((i * 29) % 52))
        let speed = 25.0 + Double((i * 17) % 20)
        let swaySpeed = 1.0 + Double((i * 13) % 5) * 0.3
        let swayAmp = CGFloat(10 + ((i * 19) % 18))
        let phase = Double(i) * 1.3
        let opacity = 0.08 + Double((i * 7) % 10) * 0.02
        return BubbleData(id: i, xRatio: x, size: s, speed: speed, swaySpeed: swaySpeed, swayAmp: swayAmp, phase: phase, opacity: opacity)
    }
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard size.width > 0 && size.height > 0 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for bubble in bubbles {
                    let totalH = size.height + bubble.size * 2
                    let rawY = fmod(time * bubble.speed + bubble.phase * 50.0, Double(totalH))
                    let y = size.height + bubble.size - CGFloat(rawY)
                    
                    let sway = sin(time * bubble.swaySpeed + bubble.phase) * bubble.swayAmp
                    let x = bubble.xRatio * size.width + sway
                    
                    let rect = CGRect(
                        x: x - bubble.size / 2,
                        y: y - bubble.size / 2,
                        width: bubble.size,
                        height: bubble.size
                    )
                    
                    let gradient = Gradient(colors: [
                        themeManager.accentColor.opacity(bubble.opacity * 1.6),
                        Color.white.opacity(bubble.opacity * 0.6),
                        Color.clear
                    ])
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            gradient,
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 0,
                            endRadius: bubble.size / 2
                        )
                    )
                    
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(themeManager.accentColor.opacity(bubble.opacity * 1.8)),
                        lineWidth: 1.0
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 2. Animación de Patrón de Hexágonos (TimelineView + Canvas)

@MainActor
public struct HexagonsAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard size.width > 0 && size.height > 0 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                let hexRadius: CGFloat = 32.0
                let hexWidth = hexRadius * sqrt(3)
                let hexHeight = hexRadius * 1.5
                
                // Desplazamiento sutil diagonal
                let driftX = CGFloat(fmod(time * 5.0, Double(hexWidth)))
                let driftY = CGFloat(fmod(time * 3.5, Double(hexHeight * 2)))
                
                let cols = Int(ceil(size.width / hexWidth)) + 2
                let rows = Int(ceil(size.height / hexHeight)) + 3
                
                for r in -1..<rows {
                    let y = CGFloat(r) * hexHeight - driftY
                    let xOffset = (r % 2 == 0) ? 0 : hexWidth / 2
                    
                    for c in -1..<cols {
                        let x = CGFloat(c) * hexWidth + xOffset - driftX
                        
                        let pulse = sin(time * 1.3 + Double(r * 3 + c * 2))
                        let alpha = max(0.015, 0.025 + 0.05 * pulse)
                        
                        let hexPath = hexagonPath(center: CGPoint(x: x, y: y), radius: hexRadius * 0.92)
                        
                        let strokeColor = (pulse > 0.4)
                            ? themeManager.accentColor.opacity(alpha * 1.8)
                            : Color.white.opacity(alpha)
                        
                        context.stroke(hexPath, with: .color(strokeColor), lineWidth: 1.0)
                        
                        if pulse > 0.85 {
                            context.fill(hexPath, with: .color(themeManager.accentColor.opacity(0.035)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func hexagonPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3.0) - (.pi / 6.0)
            let pt = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 3. Animación de Ondas de Aurora Boreal (TimelineView + Canvas sin glitches)

@MainActor
public struct AuroraAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard size.width > 0 && size.height > 0 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Esfera 1: Color de acento (órbita superior)
                let x1 = size.width * 0.45 + CGFloat(sin(time * 0.35)) * (size.width * 0.28)
                let y1 = size.height * 0.28 + CGFloat(cos(time * 0.28)) * (size.height * 0.16)
                let r1 = size.width * 0.75
                let rect1 = CGRect(x: x1 - r1, y: y1 - r1, width: r1 * 2, height: r1 * 2)
                
                context.fill(
                    Path(ellipseIn: rect1),
                    with: .radialGradient(
                        Gradient(colors: [
                            themeManager.accentColor.opacity(0.18),
                            themeManager.accentColor.opacity(0.06),
                            Color.clear
                        ]),
                        center: CGPoint(x: x1, y: y1),
                        startRadius: 0,
                        endRadius: r1
                    )
                )
                
                // Esfera 2: Violeta eléctrico profundo (órbita inferior)
                let x2 = size.width * 0.55 + CGFloat(cos(time * 0.25)) * (size.width * 0.26)
                let y2 = size.height * 0.72 + CGFloat(sin(time * 0.32)) * (size.height * 0.18)
                let r2 = size.width * 0.82
                let rect2 = CGRect(x: x2 - r2, y: y2 - r2, width: r2 * 2, height: r2 * 2)
                
                context.fill(
                    Path(ellipseIn: rect2),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.45, green: 0.2, blue: 0.9).opacity(0.16),
                            Color(red: 0.3, green: 0.1, blue: 0.7).opacity(0.05),
                            Color.clear
                        ]),
                        center: CGPoint(x: x2, y: y2),
                        startRadius: 0,
                        endRadius: r2
                    )
                )
                
                // Esfera 3: Cian suave ambiental (órbita central)
                let x3 = size.width * 0.5 + CGFloat(sin(time * 0.22 + 1.8)) * (size.width * 0.24)
                let y3 = size.height * 0.48 + CGFloat(cos(time * 0.38 + 1.2)) * (size.height * 0.15)
                let r3 = size.width * 0.68
                let rect3 = CGRect(x: x3 - r3, y: y3 - r3, width: r3 * 2, height: r3 * 2)
                
                context.fill(
                    Path(ellipseIn: rect3),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.08, green: 0.72, blue: 0.85).opacity(0.14),
                            Color(red: 0.05, green: 0.5, blue: 0.6).opacity(0.04),
                            Color.clear
                        ]),
                        center: CGPoint(x: x3, y: y3),
                        startRadius: 0,
                        endRadius: r3
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Animación de Polvo Estelar (TimelineView + Canvas)

@MainActor
public struct StardustAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public struct StarData: Identifiable, Sendable {
        public let id: Int
        public let xRatio: CGFloat
        public let yRatio: CGFloat
        public let size: CGFloat
        public let speed: Double
        public let phase: Double
    }
    
    private let stars: [StarData] = (0..<36).map { i in
        let x = CGFloat((i * 41 + 17) % 100) / 100.0
        let y = CGFloat((i * 59 + 23) % 100) / 100.0
        let s = CGFloat(1.5 + Double((i * 13) % 4) * 0.8)
        let speed = 1.0 + Double((i * 7) % 5) * 0.4
        let phase = Double(i) * 0.75
        return StarData(id: i, xRatio: x, yRatio: y, size: s, speed: speed, phase: phase)
    }
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard size.width > 0 && size.height > 0 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for star in stars {
                    let rawY = fmod(star.yRatio * size.height - CGFloat(time * 7.5 * star.speed), size.height)
                    let y = rawY < 0 ? rawY + size.height : rawY
                    let x = star.xRatio * size.width + CGFloat(sin(time * 0.75 + star.phase) * 6.0)
                    
                    let twinkle = sin(time * star.speed * 2.2 + star.phase)
                    let alpha = max(0.12, 0.32 + 0.45 * twinkle)
                    
                    let rect = CGRect(x: x - star.size / 2, y: y - star.size / 2, width: star.size, height: star.size)
                    
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
                    
                    if twinkle > 0.4 {
                        let glowRect = CGRect(x: x - star.size * 1.5, y: y - star.size * 1.5, width: star.size * 3, height: star.size * 3)
                        context.fill(Path(ellipseIn: glowRect), with: .color(themeManager.accentColor.opacity(alpha * 0.35)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Selector Reutilizable de Animación de Fondo

@MainActor
public struct BackgroundAnimationPickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(BackgroundAnimationPreset.allCases) { preset in
                let isSelected = themeManager.backgroundAnimation == preset
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        themeManager.backgroundAnimation = preset
                    }
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isSelected ? themeManager.accentColor.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: preset.iconName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isSelected ? themeManager.accentColor : .gray)
                        }
                        
                        Text(preset.rawValue)
                            .font(.caption2)
                            .fontWeight(isSelected ? .bold : .medium)
                            .foregroundColor(isSelected ? .white : .gray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? themeManager.accentColor.opacity(0.12) : Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? themeManager.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                    )
                    .scaleEffect(isSelected ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
