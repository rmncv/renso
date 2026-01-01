import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    CardView {
        VStack(alignment: .leading) {
            Text("Card Title")
                .font(.headline)
            Text("Card content goes here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}
