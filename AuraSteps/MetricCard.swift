import SwiftUI

/// Componente reutilizable para cada tarjeta de métrica secundaria con soporte para micro-animaciones al pulsar.
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let cardColor: Color
    let accentColor: Color
    var isPressed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(accentColor)
                    .scaleEffect(isPressed ? 1.25 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardColor)
        .cornerRadius(18)
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .shadow(color: isPressed ? accentColor.opacity(0.3) : .clear, radius: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
