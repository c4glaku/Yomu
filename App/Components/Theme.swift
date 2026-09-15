import SwiftUI
import YomuCore

enum Theme {
    static let orange = Color(red: 0.96, green: 0.32, blue: 0.16)
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1) : UIColor(red: 0.975, green: 0.967, blue: 0.95, alpha: 1) })
    static let surface = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : .white })
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let line = Color.primary.opacity(0.09)
    static let paleOrange = orange.opacity(0.09)
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Theme.orange, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct CircleIconButton: View {
    var symbol: String
    var label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                .frame(width: 46, height: 46).background(Theme.surface, in: Circle())
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(.secondary) }
}

struct BrandMark: View {
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29).fill(Theme.orange)
            Image(systemName: "book.pages.fill").font(.system(size: size * 0.5, weight: .medium)).foregroundStyle(.white)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct BookCover: View {
    let book: LibraryBook
    var coverURL: URL? = nil
    var compact = false
    private var palette: (Color, Color) {
        switch book.coverStyle % 4 {
        case 1: (Color(red: 0.20, green: 0.28, blue: 0.30), Color(red: 0.91, green: 0.81, blue: 0.65))
        case 2: (Color(red: 0.74, green: 0.77, blue: 0.66), Color(red: 0.20, green: 0.29, blue: 0.25))
        case 3: (Color(red: 0.24, green: 0.23, blue: 0.25), Color(red: 0.91, green: 0.75, blue: 0.67))
        default: (Color(red: 0.94, green: 0.38, blue: 0.22), Color(red: 1, green: 0.91, blue: 0.73))
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let coverURL, let image = UIImage(contentsOfFile: coverURL.path) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    palette.0
                    Circle().stroke(palette.1.opacity(0.25), lineWidth: 1).frame(width: geometry.size.width * 0.95).offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.25)
                    Circle().stroke(palette.1.opacity(0.25), lineWidth: 1).frame(width: geometry.size.width * 0.72).offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.25)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("YOMU EDITIONS").font(.system(size: compact ? 5 : 8, weight: .semibold, design: .monospaced)).tracking(1).lineLimit(1).minimumScaleFactor(0.6)
                            Spacer()
                            Image(systemName: "sun.max").font(.system(size: compact ? 9 : 14))
                        }.opacity(0.8)
                        Rectangle().frame(height: 0.5).opacity(0.45)
                        Text(book.title).font(.system(size: compact ? 21 : 32, weight: .regular, design: .serif))
                            .lineSpacing(compact ? 2 : 5).lineLimit(4).minimumScaleFactor(0.6).layoutPriority(1)
                        Spacer(minLength: 0)
                        Text(book.format == .sample ? "A SMALL STEP" : book.format.label)
                            .font(.system(size: compact ? 6 : 9, weight: .medium, design: .monospaced)).tracking(1.5)
                    }.padding(compact ? 13 : 21).foregroundStyle(palette.1)
                    HStack(spacing: 0) {
                        Rectangle().fill(.black.opacity(0.08)).frame(width: 5)
                        Rectangle().fill(.white.opacity(0.16)).frame(width: 1)
                        Spacer()
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 5))
        }.aspectRatio(0.7, contentMode: .fit)
            .shadow(color: .black.opacity(0.13), radius: 9, x: 2, y: 6)
            .accessibilityLabel("Cover of \(book.title)")
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 36, weight: .light)).foregroundStyle(Theme.orange)
                .frame(width: 80, height: 80).background(Theme.paleOrange, in: RoundedRectangle(cornerRadius: 24))
            Text(title).font(.title3.weight(.semibold))
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 310)
        }.frame(maxWidth: .infinity).padding(.vertical, 48)
    }
}
