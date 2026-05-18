import SwiftUI

struct AppBrandHeader: View {
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            Text("商")
                .font(.headline.weight(.black))
                .foregroundColor(compact ? .white : .white)
                .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.28)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Shoko Forms")
                    .font(compact ? .subheadline.weight(.black) : .headline.weight(.black))
                Text("日本商業帳票作成")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(compact ? .appMuted : Color.white.opacity(0.72))
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.black))
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPanel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.08)))
    }
}

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.appMuted)
            content
        }
    }
}
