import SwiftUI

public struct CatIllustrationView: View {
    public let stage: CatStage
    public let breed: CatBreed
    public let remainingPercent: Double
    public let animFrame: Int
    public let targetLabel: String
    
    @State private var localFrame: Int = 0
    private let popoverAnimTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(
        stage: CatStage,
        breed: CatBreed = .gingerTabby,
        remainingPercent: Double,
        animFrame: Int,
        targetLabel: String = ""
    ) {
        self.stage = stage
        self.breed = breed
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
                    // Cute Chubby Retro Pixel Art Display Frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        
                        // Pixel art drop shadow for depth
                        PixelArtCanvas(stage: stage, breed: breed, frameIndex: displayFrame)
                            .offset(x: 1.5, y: 1.5)
                            .opacity(0.12)
                        
                        PixelArtCanvas(stage: stage, breed: breed, frameIndex: displayFrame)
                    }
                    .frame(width: 84, height: 68)
                    
                    // Status & Quote
                    VStack(alignment: .leading, spacing: 5) {
                        // Row 1: Emoji + Stage Title + Remaining Percent Badge
                        HStack(alignment: .center, spacing: 4) {
                            Text(breed.emoji)
                                .font(.system(size: 13))
                            Text(stage.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            Spacer(minLength: 4)
                            
                            Text("잔여 \(Int(remainingPercent))%")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(stage.accentColor.opacity(0.2))
                                .foregroundColor(stage.accentColor)
                                .clipShape(Capsule())
                                .fixedSize()
                        }
                        
                        // Row 2: Breed Badge + Target Label (never truncated!)
                        HStack(spacing: 5) {
                            Text(breed.shortName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(stage.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(stage.accentColor.opacity(0.12))
                                .cornerRadius(4)
                                .fixedSize(horizontal: true, vertical: false)
                            
                            if !targetLabel.isEmpty {
                                Text(targetLabel)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        // Row 3: Quote
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
            .frame(minHeight: 88)
        }
        .onReceive(popoverAnimTimer) { _ in
            localFrame = (localFrame + 1) % 2
        }
    }
}

// MARK: - Chubby Pixel Art Palette (Faithful to Reference Breeds)
struct CatPalette {
    let outline: Color
    let coat: Color
    let stripe: Color
    let chest: Color
    let pink: Color
    let sleepZ: Color
}

// MARK: - Pixel Art Canvas
public struct PixelArtCanvas: View {
    public let stage: CatStage
    public let breed: CatBreed
    public let frameIndex: Int
    
    public init(stage: CatStage, breed: CatBreed, frameIndex: Int = 0) {
        self.stage = stage
        self.breed = breed
        self.frameIndex = frameIndex
    }
    
    public var body: some View {
        Canvas { context, size in
            let grids = PixelArtFrames.rawGrids(for: stage)
            guard !grids.isEmpty else { return }
            let currentGrid = grids[frameIndex % grids.count]
            
            let gridHeight = currentGrid.count
            let gridWidth = currentGrid.first?.count ?? 20
            
            let pixelSize: CGFloat = min(size.width / CGFloat(gridWidth), size.height / CGFloat(gridHeight))
            let xOffset = (size.width - CGFloat(gridWidth) * pixelSize) / 2
            let yOffset = (size.height - CGFloat(gridHeight) * pixelSize) / 2
            
            let palette = paletteForBreed(breed)
            
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
                    case "S":
                        context.fill(Path(rect), with: .color(palette.stripe))
                    case "W":
                        context.fill(Path(rect), with: .color(palette.chest))
                    case "P":
                        context.fill(Path(rect), with: .color(palette.pink))
                    case "Z", "z":
                        context.fill(Path(rect), with: .color(palette.sleepZ))
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func paletteForBreed(_ breed: CatBreed) -> CatPalette {
        switch breed {
        case .gingerTabby:
            // 🧀 Ginger Tabby (Reference Cat 1)
            return CatPalette(
                outline: Color(red: 0.17, green: 0.14, blue: 0.25), // #2B233F deep purple charcoal
                coat: Color(red: 0.98, green: 0.60, blue: 0.31),   // #FA9A50 warm rich ginger
                stripe: Color(red: 0.85, green: 0.42, blue: 0.15), // #D96B27 caramel tiger stripe
                chest: Color(red: 1.00, green: 0.96, blue: 0.93),  // #FFF5EE creamy white V-bib
                pink: Color(red: 0.95, green: 0.48, blue: 0.54),   // #F27A8A strawberry pink ears
                sleepZ: Color(red: 0.35, green: 0.75, blue: 1.00)
            )
        case .britishBlue:
            // 🫐 British Shorthair Blue/Gray (Reference Cat 2)
            return CatPalette(
                outline: Color(red: 0.12, green: 0.14, blue: 0.23), // #1E243A deep navy charcoal
                coat: Color(red: 0.42, green: 0.56, blue: 0.66),   // #6B8EA8 silky slate blue
                stripe: Color(red: 0.31, green: 0.44, blue: 0.53), // #506F87 darker blue shadow
                chest: Color(red: 0.65, green: 0.77, blue: 0.86),  // #A5C4DB soft powder blue chest
                pink: Color(red: 0.94, green: 0.47, blue: 0.53),   // #F07888 coral pink ears
                sleepZ: Color(red: 0.35, green: 0.75, blue: 1.00)
            )
        case .creamWhite:
            // 🥛 Cream White Cat (Reference Cat 3)
            return CatPalette(
                outline: Color(red: 0.18, green: 0.16, blue: 0.22), // #2E2838 soft dark charcoal
                coat: Color(red: 0.97, green: 0.93, blue: 0.89),   // #F8ECE2 warm cream coat
                stripe: Color(red: 0.90, green: 0.82, blue: 0.75), // #E5D0BF sand accent
                chest: Color(red: 1.00, green: 1.00, blue: 1.00),  // #FFFFFF pure white chest
                pink: Color(red: 0.93, green: 0.64, blue: 0.68),   // #EDA2AD sleepy rose ears
                sleepZ: Color(red: 0.31, green: 0.71, blue: 0.97)  // #50B4F8 sky cyan Zzz
            )
        case .calico:
            // 🌸 Calico (Reference Cat 4)
            return CatPalette(
                outline: Color(red: 0.18, green: 0.11, blue: 0.16), // #2D1C2A deep berry charcoal
                coat: Color(red: 0.99, green: 0.92, blue: 0.90),   // #FCEAE6 milk cream
                stripe: Color(red: 0.94, green: 0.51, blue: 0.31), // #F08250 apricot orange patch
                chest: Color(red: 0.77, green: 0.31, blue: 0.41),  // #C44E68 raspberry patch
                pink: Color(red: 1.00, green: 0.26, blue: 0.47),   // #FF4278 bright blep tongue!
                sleepZ: Color(red: 0.25, green: 0.78, blue: 0.94)
            )
        case .goldenBicolor:
            // 🍯 Golden Bicolor (Reference Cat 5)
            return CatPalette(
                outline: Color(red: 0.16, green: 0.12, blue: 0.14), // #2A1E24 deep charcoal
                coat: Color(red: 0.97, green: 0.67, blue: 0.16),   // #F8AC28 warm golden yellow
                stripe: Color(red: 0.87, green: 0.54, blue: 0.08), // #DF8A14 darker gold shade
                chest: Color(red: 1.00, green: 1.00, blue: 1.00),  // #FFFFFF pure white chest & paws
                pink: Color(red: 0.96, green: 0.55, blue: 0.59),   // #F48B96 peach rose ears
                sleepZ: Color(red: 0.35, green: 0.75, blue: 1.00)
            )
        case .siamese:
            // ☕️ Siamese (Reference Cat 6)
            return CatPalette(
                outline: Color(red: 0.14, green: 0.09, blue: 0.11), // #24161C dark espresso
                coat: Color(red: 0.95, green: 0.87, blue: 0.81),   // #F2DFCE warm latte cream
                stripe: Color(red: 0.56, green: 0.29, blue: 0.21), // #8E4A35 seal point mask & paws
                chest: Color(red: 1.00, green: 0.96, blue: 0.92),  // #FFF4EB light cream bib
                pink: Color(red: 0.90, green: 0.45, blue: 0.52),   // #E67385 soft rose
                sleepZ: Color(red: 0.00, green: 0.88, blue: 1.00)  // #00E0FF electric cyan Zzz
            )
        }
    }
}
