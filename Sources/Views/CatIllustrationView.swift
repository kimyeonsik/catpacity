import SwiftUI

public struct CatIllustrationView: View {
    public let stage: CatStage
    public let remainingPercent: Double
    public let animFrame: Int
    public let targetLabel: String
    
    @State private var localFrame: Int = 0
    private let popoverAnimTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(stage: CatStage, remainingPercent: Double, animFrame: Int, targetLabel: String = "") {
        self.stage = stage
        self.remainingPercent = remainingPercent
        self.animFrame = animFrame
        self.targetLabel = targetLabel
    }
    
    public var body: some View {
        let displayFrame = animFrame > 0 ? animFrame : localFrame
        
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
                
                HStack(spacing: 12) {
                    // Fine-pitch Retro Pixel Art Screen Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.65))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        
                        // Pixel art drop shadow for depth
                        PixelArtCanvas(stage: stage, frameIndex: displayFrame)
                            .offset(x: 1.5, y: 1.5)
                            .opacity(0.12)
                        
                        PixelArtCanvas(stage: stage, frameIndex: displayFrame)
                    }
                    .frame(width: 96, height: 62)
                    
                    // Status & Quote
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 5) {
                            Text(stage.emoji)
                                .font(.system(size: 15))
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stage.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                
                                if !targetLabel.isEmpty {
                                    Text(targetLabel)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer(minLength: 4)
                            
                            Text("잔여 \(Int(remainingPercent))%")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(stage.accentColor.opacity(0.2))
                                .foregroundColor(stage.accentColor)
                                .clipShape(Capsule())
                                .fixedSize()
                                .layoutPriority(1)
                        }
                        
                        Text("\"\(stage.quote)\"")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(minHeight: 82)
        }
        .onReceive(popoverAnimTimer) { _ in
            localFrame = (localFrame + 1) % 2
        }
    }
}

// MARK: - Fine-Pitch Pixel Art Palette
struct CatPalette {
    let outline: Color
    let coat: Color
    let highlight: Color
    let pink: Color
    let eyes: Color
    let white: Color
    let features: Color
    let sleepZ: Color
}

// MARK: - Fine-Pitch Pixel Art Canvas
struct PixelArtCanvas: View {
    let stage: CatStage
    let frameIndex: Int
    
    var body: some View {
        Canvas { context, size in
            let grids = PixelArtFrames.rawGrids(for: stage)
            guard !grids.isEmpty else { return }
            let currentGrid = grids[frameIndex % grids.count]
            
            let gridHeight = currentGrid.count
            let gridWidth = currentGrid.first?.count ?? 28
            
            let pixelSize: CGFloat = min(size.width / CGFloat(gridWidth), size.height / CGFloat(gridHeight))
            let xOffset = (size.width - CGFloat(gridWidth) * pixelSize) / 2
            let yOffset = (size.height - CGFloat(gridHeight) * pixelSize) / 2
            
            let palette = paletteForStage(stage)
            
            for (y, row) in currentGrid.enumerated() {
                for (x, char) in row.enumerated() {
                    let rect = CGRect(
                        x: xOffset + CGFloat(x) * pixelSize,
                        y: yOffset + CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    
                    switch char {
                    case "B":
                        context.fill(Path(rect), with: .color(palette.outline))
                    case "C":
                        context.fill(Path(rect), with: .color(palette.coat))
                    case "H":
                        context.fill(Path(rect), with: .color(palette.highlight))
                    case "P":
                        context.fill(Path(rect), with: .color(palette.pink))
                    case "E":
                        context.fill(Path(rect), with: .color(palette.eyes))
                    case "W":
                        context.fill(Path(rect), with: .color(palette.white))
                    case "-", "x":
                        context.fill(Path(rect), with: .color(palette.features))
                    case "Z", "z":
                        context.fill(Path(rect), with: .color(palette.sleepZ))
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func paletteForStage(_ stage: CatStage) -> CatPalette {
        switch stage {
        case .energetic:
            return CatPalette(
                outline: Color(red: 0.16, green: 0.10, blue: 0.08), // Rich warm espresso
                coat: Color(red: 1.00, green: 0.62, blue: 0.15),   // Lively golden ginger
                highlight: Color(red: 1.00, green: 0.94, blue: 0.82), // Soft cream
                pink: Color(red: 1.00, green: 0.48, blue: 0.64),   // Sweet strawberry pink
                eyes: Color(red: 0.06, green: 0.72, blue: 0.42),   // Sparkling emerald green
                white: Color.white,
                features: Color(red: 0.16, green: 0.10, blue: 0.08),
                sleepZ: Color(red: 0.35, green: 0.75, blue: 1.00)
            )
        case .content:
            return CatPalette(
                outline: Color(red: 0.20, green: 0.14, blue: 0.10), // Warm roast brown
                coat: Color(red: 0.98, green: 0.72, blue: 0.32),   // Cozy honey caramel
                highlight: Color(red: 1.00, green: 0.96, blue: 0.86), // Buttermilk cream
                pink: Color(red: 1.00, green: 0.55, blue: 0.65),   // Peach blush
                eyes: Color(red: 0.20, green: 0.14, blue: 0.10),
                white: Color.white,
                features: Color(red: 0.20, green: 0.14, blue: 0.10),
                sleepZ: Color(red: 0.35, green: 0.75, blue: 1.00)
            )
        case .tired:
            return CatPalette(
                outline: Color(red: 0.16, green: 0.20, blue: 0.26), // Deep charcoal slate
                coat: Color(red: 0.64, green: 0.72, blue: 0.84),   // Silky lavender blue
                highlight: Color(red: 0.92, green: 0.94, blue: 0.98), // Misty pearl
                pink: Color(red: 0.95, green: 0.60, blue: 0.70),   // Dusty rose
                eyes: Color(red: 0.16, green: 0.20, blue: 0.26),
                white: Color.white,
                features: Color(red: 0.16, green: 0.20, blue: 0.26),
                sleepZ: Color(red: 0.20, green: 0.70, blue: 1.00)  // Sky cyan Z
            )
        case .melting:
            return CatPalette(
                outline: Color(red: 0.28, green: 0.10, blue: 0.22), // Deep blackberry
                coat: Color(red: 0.98, green: 0.58, blue: 0.66),   // Strawberry mochi pink
                highlight: Color(red: 1.00, green: 0.92, blue: 0.95), // Marshmallow white
                pink: Color(red: 1.00, green: 0.25, blue: 0.52),   // Vivid blep tongue!
                eyes: Color(red: 0.28, green: 0.10, blue: 0.22),
                white: Color(red: 0.30, green: 0.85, blue: 1.00),  // Glistening sweat drop
                features: Color(red: 0.28, green: 0.10, blue: 0.22),
                sleepZ: Color(red: 0.30, green: 0.85, blue: 1.00)
            )
        case .liquid:
            return CatPalette(
                outline: Color(red: 0.12, green: 0.10, blue: 0.30), // Deep midnight ink
                coat: Color(red: 0.56, green: 0.46, blue: 0.96),   // Luminescent jelly purple
                highlight: Color(red: 0.82, green: 0.78, blue: 1.00), // Glowing lilac
                pink: Color(red: 1.00, green: 0.38, blue: 0.68),   // Neon pink
                eyes: Color(red: 0.12, green: 0.10, blue: 0.30),
                white: Color(red: 0.20, green: 0.90, blue: 1.00),  // Glowing bubble
                features: Color(red: 0.12, green: 0.10, blue: 0.30),
                sleepZ: Color(red: 0.00, green: 0.92, blue: 1.00)  // Bright electric cyan Z
            )
        }
    }
}
