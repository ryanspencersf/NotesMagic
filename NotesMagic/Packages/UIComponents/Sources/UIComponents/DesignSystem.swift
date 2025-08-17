import SwiftUI

// MARK: - NotesMagic Design System
// Minimal, production-minded tokens and helpers used across iOS + macOS.
// All public so other packages (Features/*) can import UIComponents and use them.

public enum DS {
    // Spacing (8pt grid, with supporting micro/mega steps)
    public enum Spacing {
        public static let micro: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let s: CGFloat = 12
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // Radius tokens
    public enum Radius {
        public static let pill: CGFloat = 12
        public static let card: CGFloat = 16
        public static let fab: CGFloat = 18
    }

    // Typography
    public enum Typography {
        public static func h1() -> Font { .system(size: 28, weight: .semibold) }
        public static func h2() -> Font { .system(size: 22, weight: .semibold) }
        public static func body() -> Font { .system(size: 17, weight: .regular) }
        public static func secondary() -> Font { .system(size: 15, weight: .regular) }
        public static func meta() -> Font { .system(size: 13, weight: .regular) }
        public static func mono() -> Font { .system(.body, design: .monospaced) }
    }

    // Colors — expect Color assets named below with Any/Dark variants
    public enum ColorToken {
        public static var bg: Color { Color("Background") }
        public static var textSecondary: Color { Color("TextSecondary") }
        public static var pillFill: Color { Color("PillFill") }
        public static var accent: Color { Color.accentColor }
    }

    // Motion
    public enum Motion {
        // Light, springy animations aligned to spec timings
        public static let appear: Animation = .interpolatingSpring(stiffness: 220, damping: 28)
        public static let contextBarIn: Animation = .easeOut(duration: 0.12)
        public static let contextBarOut: Animation = .easeOut(duration: 0.08)
        public static let diffSlide: Animation = .easeOut(duration: 0.14)
        public static let highlightPulse: Animation = .easeInOut(duration: 0.20)
    }

    // Shadows
    public enum Shadow {
        public static func raised(color: Color = .black.opacity(0.35)) -> (radius: CGFloat, x: CGFloat, y: CGFloat, color: Color) {
            (12, 0, 8, color)
        }
    }
}

// MARK: - View helpers

public extension View {
    // Apply a subtle card style with flat or glass background
    func cardBackground(glass: Bool = false) -> some View {
        modifier(CardBackground(glass: glass))
    }

    // Pill visual used for tags/suggestions; quiet by default
    func pillStyle() -> some View { modifier(PillStyle()) }

    // 1px hairline stroke for edge clarity on dark backgrounds
    func hairline(_ opacity: Double = 0.12) -> some View {
        overlay(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous).stroke(Color.white.opacity(opacity)))
    }
}

private struct CardBackground: ViewModifier {
    let glass: Bool
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.m)
            .background(
                Group {
                    if glass {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                            .fill(DS.ColorToken.bg)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            )
    }
}

private struct PillStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}

// MARK: - Diff highlight utility
public struct DiffHighlight: View {
    public enum Kind { case added, removed }
    public let text: String
    public let kind: Kind
    public init(_ text: String, kind: Kind) { self.text = text; self.kind = kind }
    public var body: some View {
        Text(text)
            .font(DS.Typography.secondary())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(kind == .added ? DS.ColorToken.accent.opacity(0.12) : Color.red.opacity(0.10))
            )
    }
}

// MARK: - Glass FAB (shared) – one source of truth
public struct GlassFAB: View {
    public var action: () -> Void
    public init(action: @escaping () -> Void) { self.action = action }
    public var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .padding(16)
        }
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        )
        .shadow(color: DS.Shadow.raised().color, radius: DS.Shadow.raised().radius, x: DS.Shadow.raised().x, y: DS.Shadow.raised().y)
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.fab, style: .continuous))
        .accessibilityLabel("New note")
    }
}

// MARK: - Shared Pill Style
extension View {
    func pill() -> some View {
        self
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
