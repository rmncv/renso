import SwiftUI

struct CategoryIconView: View {
    let iconName: String
    let colorHex: String
    let size: CGFloat

    init(iconName: String, colorHex: String, size: CGFloat = 24) {
        self.iconName = iconName
        self.colorHex = colorHex
        self.size = size
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.6))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex))
            .cornerRadius(size / 4)
    }
}

#Preview {
    HStack(spacing: 20) {
        CategoryIconView(iconName: "cart.fill", colorHex: "#34C759", size: 32)
        CategoryIconView(iconName: "fork.knife", colorHex: "#FF9500", size: 40)
        CategoryIconView(iconName: "car.fill", colorHex: "#007AFF", size: 48)
    }
    .padding()
}
