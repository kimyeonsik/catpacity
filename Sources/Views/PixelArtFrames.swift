import AppKit

public class PixelArtFrames {
    
    // Cache pre-rendered NSImages: [Key: [NSImage]]
    // Key format: "\(breed.rawValue)_\(stage.rawValue)"
    private static var cachedFrames: [String: [NSImage]] = [:]
    
    public static func getFrames(for stage: CatStage, breed: CatBreed = .gingerTabby) -> [NSImage] {
        let key = "\(breed.rawValue)_\(stage.rawValue)"
        if let frames = cachedFrames[key] {
            return frames
        }
        
        let gridFrames = rawGrids(for: stage)
        let images = gridFrames.map { renderImage(grid: $0, breed: breed, scale: 1.0) }
        cachedFrames[key] = images
        return images
    }
    
    public static func getLargeFrame(for stage: CatStage, breed: CatBreed = .gingerTabby, frameIndex: Int) -> NSImage {
        let gridFrames = rawGrids(for: stage)
        let safeIndex = frameIndex % max(1, gridFrames.count)
        return renderImage(grid: gridFrames[safeIndex], breed: breed, scale: 3.0)
    }
    
    public static func clearCache() {
        cachedFrames.removeAll()
    }
    
    private static func renderImage(grid: [String], breed: CatBreed, scale: CGFloat) -> NSImage {
        let height = grid.count
        let width = grid.first?.count ?? 0
        let size = NSSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        
        // Alpha weights for menu bar template rendering based on breed
        let (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha): (CGFloat, CGFloat, CGFloat, CGFloat)
        switch breed {
        case .gingerTabby:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.60, 0.78, 0.25, 0.35)
        case .britishBlue:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.65, 0.75, 0.40, 0.35)
        case .creamWhite:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.35, 0.50, 0.15, 0.35)
        case .calico:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.45, 0.75, 0.65, 0.40)
        case .goldenBicolor:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.62, 0.72, 0.20, 0.35)
        case .siamese:
            (coatAlpha, stripeAlpha, chestAlpha, pinkAlpha) = (0.40, 0.85, 0.18, 0.35)
        }
        
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.interpolationQuality = .none
            
            for (y, row) in grid.enumerated() {
                let actualY = height - 1 - y // Cocoa flipped coordinate
                for (x, char) in row.enumerated() {
                    let pixelRect = CGRect(
                        x: CGFloat(x) * scale,
                        y: CGFloat(actualY) * scale,
                        width: scale,
                        height: scale
                    )
                    
                    switch char {
                    case "B":
                        // Solid outline & facial features (pure white in dark mode, pure black in light mode)
                        ctx.setFillColor(NSColor.black.cgColor)
                        ctx.fill(pixelRect)
                    case "S":
                        // Dark stripes / pattern mask
                        ctx.setFillColor(NSColor.black.withAlphaComponent(stripeAlpha).cgColor)
                        ctx.fill(pixelRect)
                    case "C":
                        // Main body coat
                        ctx.setFillColor(NSColor.black.withAlphaComponent(coatAlpha).cgColor)
                        ctx.fill(pixelRect)
                    case "P":
                        // Inner ear & tongue accent
                        ctx.setFillColor(NSColor.black.withAlphaComponent(pinkAlpha).cgColor)
                        ctx.fill(pixelRect)
                    case "W":
                        // White chest bib / underbelly
                        ctx.setFillColor(NSColor.black.withAlphaComponent(chestAlpha).cgColor)
                        ctx.fill(pixelRect)
                    case "Z", "z":
                        // Sleep Zzz
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.80).cgColor)
                        ctx.fill(pixelRect)
                    default:
                        // Transparent cutout background
                        break
                    }
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    
    public static func rawGrids(for stage: CatStage) -> [[String]] {
        switch stage {
        case .energetic:
            return energeticGrids
        case .content:
            return contentGrids
        case .tired:
            return tiredGrids
        case .melting:
            return meltingGrids
        case .liquid:
            return liquidGrids
        }
    }
    
    // MARK: - Stage 1: Energetic (20x18) - Standing tall, proud ears, wagging tail
    private static let energeticGrids: [[String]] = [
        [
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BSCB",
            "..BSCWCCCCCWCSBBCSB.",
            ".BCCCCWCCCWCCCCBSB..",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBSB..",
            ".BSSSCCWWWCCSSSBCB..",
            ".BSCCBCCWCCBCCSBSB..",
            ".BCCCBSBCBSBCCCBB...",
            "..BCCBCBCBCBCCB.....",
            "...BBB.BBB.BBB......",
            ".....BBB.BBB........"
        ],
        [
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB....BB.",
            "...BCCCCSCCCCB..BCCB",
            "...BCBBCCCBBCB..BCCB",
            "...BCCCCBCCCCB.BCCB.",
            "..BCCCCBCBCCCCBBCB..",
            "..BSCWCCCCCWCSBBCB..",
            ".BCCCCWCCCWCCCCBCB..",
            ".BCCCCWWWWWCCCCBSB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBSB..",
            ".BSSSCCWWWCCSSSBCB..",
            ".BSCCBCCWCCBCCSBSB..",
            ".BCCCBSBCBSBCCCBB...",
            "..BCCBCBCBCBCCB.....",
            "...BBB.BBB.BBB......",
            ".....BBB.BBB........"
        ]
    ]
    
    // MARK: - Stage 2: Content (20x18) - Cozy loaf, tucked paws, rounded bottom, relaxed eyes
    private static let contentGrids: [[String]] = [
        [
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BSCB",
            "..BSCWCCCCCWCSBBCSB.",
            ".BCCCCWCCCWCCCCBSB..",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BSSSCCWWWCCSSSBSB..",
            ".BSCCCCCCCCCCCCBCB..",
            ".BCCCBBCCCCBBCCCBB..",
            ".BCCCPBCCCCBPCCB....",
            "..BCCCCCCCCCCCCB....",
            "...BBBBBBBBBBBB....."
        ],
        [
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB....BB.",
            "...BCCCCSCCCCB..BCCB",
            "...BCBBCCCBBCB..BCCB",
            "...BCCCCBCCCCB.BCCB.",
            "..BCCCCBCBCCCCBBCB..",
            "..BSCWCCCCCWCSBBCB..",
            ".BCCCCWCCCWCCCCBCB..",
            ".BCCCCWWWWWCCCCBSB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BSSSCCWWWCCSSSBSB..",
            ".BSCCCCCCCCCCCCBCB..",
            ".BCCCBBCCCCBBCCCBB..",
            ".BCCCPBCCCCBPCCB....",
            "..BCCCCCCCCCCCCB....",
            "...BBBBBBBBBBBB....."
        ]
    ]
    
    // MARK: - Stage 3: Tired (20x18) - Slumped posture, drooped ears, sleepy eyes, drifting Zzz
    private static let tiredGrids: [[String]] = [
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            ".....B.....B........",
            "....BPB...BPB.......",
            "...BPPPBBBPPPB......",
            "..BCCCCCSCCCCB......",
            "..BCCBBCCCBBCB......",
            "..BCCCCCBCCCCB......",
            "..BCCCCBCBCCCCB..BB.",
            ".BBSCWCCCCCWCSB.BSCB",
            ".BCCCCWCCCWCCCCBBCB.",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBBCCCCBBCCCB...",
            "..BCCCCCCCCCCCCB....",
            "...BBBBBBBBBBBB....."
        ],
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            ".............zz.....",
            "..............z.....",
            ".....B.....B.zz.....",
            "....BPB...BPB.......",
            "...BPPPBBBPPPB......",
            "..BCCCCCSCCCCB......",
            "..BCCBBCCCBBCB......",
            "..BCCCCCBCCCCB...BB.",
            ".BCCCCBCBCCCCB..BCCB",
            ".BCCCCWWWWWCCCCBBCB.",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBBCCCCBBCCCB...",
            "..BCCCCCCCCCCCCB....",
            "...BBBBBBBBBBBB....."
        ]
    ]
    
    // MARK: - Stage 4: Melting (20x18) - Drooping mochi, sagging cheeks, pink blep tongue!
    private static let meltingGrids: [[String]] = [
        [
            "....................",
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "..BCCCCCBCCCCCB.....",
            "..BCCCCBCBCCCCB..BB.",
            ".BCCCCBPPBCCCCB.BCCB",
            ".BCCCCWPPWCCCCBBCB..",
            "BCCCCCWWWWWCCCCBCB..",
            "BCCCCCCCCCCCCCCBCB..",
            "BCCCCCCCCCCCCCCCBB..",
            "BCCCCCCCCCCCCCCCCB..",
            ".BBBBBBBBBBBBBBBB..."
        ],
        [
            "....................",
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "..BCCCCCBCCCCCB..BB.",
            "..BCCCCBCBCCCCB.BCCB",
            ".BCCCCBPPBCCCCBBCCB.",
            ".BCCCCWPPWCCCCBCB...",
            "BCCCCCWWWWWCCCCBCB..",
            "BCCCCCCCCCCCCCCBCB..",
            "BCCCCCCCCCCCCCCBB...",
            "BCCCCCCCCCCCCCCCB...",
            ".BBBBBBBBBBBBBBB...."
        ]
    ]
    
    // MARK: - Stage 5: Liquid (20x18) - Pancake puddle flat on the floor, snore Zzz
    private static let liquidGrids: [[String]] = [
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            "....................",
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "..BCCCCCBCCCCCB..BB.",
            "..BCCCCBCBCCCCB.BCCB",
            "BCCCCCCCCCCCCCCBBCB.",
            "BCCCCCCCCCCCCCCCCBB.",
            ".BBBBBBBBBBBBBBBBB.."
        ],
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            ".............zz.....",
            "..............z.....",
            ".............zz.....",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "..BCCCCCBCCCCCB..BB.",
            "..BCCCCBCBCCCCB.BCCB",
            "BCCCCCCCCCCCCCCBBCB.",
            "BCCCCCCCCCCCCCCCCBB.",
            ".BBBBBBBBBBBBBBBBB.."
        ]
    ]
}
