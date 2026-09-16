import SwiftUI

public struct CatIllustrationView: View {
    public let stage: CatStage
    public let remainingPercent: Double
    public let animFrame: Int
    
    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Retro arcade style container background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                stage.accentColor.opacity(0.18),
                                Color(NSColor.controlBackgroundColor).opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(stage.accentColor.opacity(0.3), lineWidth: 1.5)
                    )
                
                HStack(spacing: 16) {
                    // Chunky Retro Pixel Art Animated Cat
                    ZStack {
                        // Pixel art shadow
                        PixelArtCanvas(stage: stage, frameIndex: animFrame)
                            .offset(x: 2, y: 2)
                            .opacity(0.15)
                        
                        PixelArtCanvas(stage: stage, frameIndex: animFrame)
                    }
                    .frame(width: 88, height: 64)
                    
                    // Status & Quote
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(stage.emoji)
                                .font(.system(size: 15))
                            Text(stage.title)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("잔여 \(Int(remainingPercent))%")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(stage.accentColor.opacity(0.2))
                                .foregroundColor(stage.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        Text("\"\(stage.quote)\"")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 80)
        }
    }
}

// MARK: - Retro Pixel Art Canvas
struct PixelArtCanvas: View {
    let stage: CatStage
    let frameIndex: Int
    
    var body: some View {
        Canvas { context, size in
            let grids = PixelArtFrames.rawGrids(for: stage)
            guard !grids.isEmpty else { return }
            let currentGrid = grids[frameIndex % grids.count]
            
            let gridHeight = currentGrid.count
            let gridWidth = currentGrid.first?.count ?? 22
            
            let pixelSize: CGFloat = min(size.width / CGFloat(gridWidth), size.height / CGFloat(gridHeight))
            let xOffset = (size.width - CGFloat(gridWidth) * pixelSize) / 2
            let yOffset = (size.height - CGFloat(gridHeight) * pixelSize) / 2
            
            // Palette based on stage
            let (bodyColor, darkColor, eyeColor, _, _) = paletteForStage(stage)
            
            for (y, row) in currentGrid.enumerated() {
                for (x, char) in row.enumerated() {
                    let rect = CGRect(
                        x: xOffset + CGFloat(x) * pixelSize,
                        y: yOffset + CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    
                    switch char {
                    case "#":
                        // Body pixels
                        context.fill(Path(rect), with: .color(bodyColor))
                        // Subtle pixel highlight on top edges
                        if y > 0 && currentGrid[y - 1][currentGrid[y - 1].index(currentGrid[y - 1].startIndex, offsetBy: x)] == "." {
                            let topHighlight = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.3)
                            context.fill(Path(topHighlight), with: .color(.white.opacity(0.25)))
                        }
                    case "x", "-":
                        context.fill(Path(rect), with: .color(eyeColor))
                    case "^":
                        context.fill(Path(rect), with: .color(darkColor))
                    case "z", "Z":
                        context.fill(Path(rect), with: .color(Color(red: 0.4, green: 0.75, blue: 1.0)))
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func paletteForStage(_ stage: CatStage) -> (Color, Color, Color, Color, Color) {
        switch stage {
        case .energetic:
            return (
                Color(red: 1.0, green: 0.65, blue: 0.25), // Energetic bright orange
                Color(red: 0.85, green: 0.45, blue: 0.15),
                Color.black,
                Color(red: 1.0, green: 0.5, blue: 0.6),
                Color.white
            )
        case .content:
            return (
                Color(red: 0.95, green: 0.65, blue: 0.35), // Cozy warm ginger
                Color(red: 0.8, green: 0.5, blue: 0.2),
                Color(red: 0.2, green: 0.2, blue: 0.2),
                Color(red: 0.95, green: 0.55, blue: 0.65),
                Color(white: 0.95)
            )
        case .tired:
            return (
                Color(red: 0.85, green: 0.6, blue: 0.45), // Subdued muted amber
                Color(red: 0.65, green: 0.45, blue: 0.3),
                Color(red: 0.3, green: 0.2, blue: 0.2),
                Color(red: 0.9, green: 0.6, blue: 0.65),
                Color(white: 0.85)
            )
        case .melting:
            return (
                Color(red: 0.8, green: 0.5, blue: 0.45), // Drooping warm blush
                Color(red: 0.6, green: 0.35, blue: 0.3),
                Color(red: 0.35, green: 0.15, blue: 0.2),
                Color(red: 0.85, green: 0.5, blue: 0.6),
                Color(white: 0.8)
            )
        case .liquid:
            return (
                Color(red: 0.7, green: 0.45, blue: 0.55), // Exhausted liquid mauve/purple
                Color(red: 0.5, green: 0.3, blue: 0.4),
                Color(red: 0.25, green: 0.1, blue: 0.2),
                Color(red: 0.8, green: 0.5, blue: 0.6),
                Color(white: 0.75)
            )
        }
    }
}
