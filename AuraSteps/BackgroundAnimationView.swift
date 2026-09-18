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

// MARK: - 1. Animación de Burbujas Flotantes

@MainActor
public struct BubblesAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public struct BubbleData: Identifiable, Sendable {
        public let id: Int
        public let xRatio: CGFloat
        public let size: CGFloat
        public let duration: Double
        public let delay: Double
        public let opacity: Double
    }
    
    // 16 burbujas distribuidas armónicamente
    private let bubbles: [BubbleData] = (0..<16).map { i in
        let pseudoX = CGFloat((i * 37 + 13) % 100) / 100.0
        let pseudoSize = CGFloat(24 + ((i * 29) % 52))
        let pseudoDuration = 7.0 + Double((i * 17) % 8)
        let pseudoDelay = Double((i * 11) % 6)
        let pseudoOpacity = 0.05 + Double((i * 7) % 10) * 0.018
        return BubbleData(id: i, xRatio: pseudoX, size: pseudoSize, duration: pseudoDuration, delay: pseudoDelay, opacity: pseudoOpacity)
    }
    
    public init() {}
    
    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            ZStack {
                ForEach(bubbles) { bubble in
                    SingleBubbleView(
                        bubble: bubble,
                        width: w,
                        height: h,
                        accentColor: themeManager.accentColor
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SingleBubbleView: View {
    let bubble: BubblesAnimationView.BubbleData
    let width: CGFloat
    let height: CGFloat
    let accentColor: Color
    
    @State private var animate = false
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        accentColor.opacity(bubble.opacity * 1.6),
                        Color.white.opacity(bubble.opacity * 0.6),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: bubble.size / 2
                )
            )
            .overlay(
                Circle()
                    .stroke(accentColor.opacity(bubble.opacity * 2.0), lineWidth: 1)
            )
            .frame(width: bubble.size, height: bubble.size)
            .position(
                x: width * bubble.xRatio + (animate ? sin(Double(bubble.id)) * 20 : -sin(Double(bubble.id)) * 20),
                y: animate ? -bubble.size : height + bubble.size
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: bubble.duration)
                    .repeatForever(autoreverses: false)
                    .delay(bubble.delay)
                ) {
                    animate = true
                }
            }
    }
}

// MARK: - 2. Animación de Patrón de Hexágonos

@MainActor
public struct HexagonsAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
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

// MARK: - 3. Animación de Ondas de Aurora Boreal

@MainActor
public struct AuroraAnimationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var startAnimation: Bool = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            ZStack {
                // Esfera 1: Color de acento
                Circle()
                    .fill(themeManager.accentColor.opacity(0.20))
                    .frame(width: w * 0.85, height: w * 0.85)
                    .blur(radius: 75)
                    .offset(
                        x: startAnimation ? -w * 0.18 : w * 0.22,
                        y: startAnimation ? -h * 0.15 : -h * 0.32
                    )
                
                // Esfera 2: Violeta eléctrico profundo
                Circle()
                    .fill(Color(red: 0.38, green: 0.18, blue: 0.85).opacity(0.18))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 80)
                    .offset(
                        x: startAnimation ? w * 0.22 : -w * 0.18,
                        y: startAnimation ? h * 0.18 : h * 0.32
                    )
                
                // Esfera 3: Cian suave ambiental
                Circle()
                    .fill(Color(red: 0.08, green: 0.65, blue: 0.82).opacity(0.14))
                    .frame(width: w * 0.72, height: w * 0.72)
                    .blur(radius: 65)
                    .offset(
                        x: startAnimation ? -w * 0.12 : w * 0.15,
                        y: startAnimation ? h * 0.04 : -h * 0.08
                    )
            }
            .frame(width: w, height: h)
            .onAppear {
                withAnimation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true)) {
                    startAnimation = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Animación de Polvo Estelar

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
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for star in stars {
                    // Movimiento vertical suave continuo
                    let rawY = fmod(star.yRatio * size.height - CGFloat(time * 7.5 * star.speed), size.height)
                    let y = rawY < 0 ? rawY + size.height : rawY
                    let x = star.xRatio * size.width + CGFloat(sin(time * 0.75 + star.phase) * 6.0)
                    
                    // Centelleo de brillo
                    let twinkle = sin(time * star.speed * 2.2 + star.phase)
                    let alpha = max(0.12, 0.32 + 0.45 * twinkle)
                    
                    let rect = CGRect(x: x - star.size / 2, y: y - star.size / 2, width: star.size, height: star.size)
                    
                    // Núcleo brillante
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
                    
                    // Resplandor de acento en destellos fuertes
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
