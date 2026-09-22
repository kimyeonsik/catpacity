import AppKit

public class PixelArtFrames {
    
    // Cache pre-rendered NSImages so switching frames is instantaneous and zero CPU overhead
    private static var cachedFrames: [CatStage: [NSImage]] = [:]
    
    public static func getFrames(for stage: CatStage) -> [NSImage] {
        if let frames = cachedFrames[stage] {
            return frames
        }
        
        let gridFrames = rawGrids(for: stage)
        let images = gridFrames.map { renderImage(grid: $0, scale: 1.0) }
        cachedFrames[stage] = images
        return images
    }
    
    public static func getLargeFrame(for stage: CatStage, frameIndex: Int) -> NSImage {
        let gridFrames = rawGrids(for: stage)
        let safeIndex = frameIndex % max(1, gridFrames.count)
        return renderImage(grid: gridFrames[safeIndex], scale: 3.0)
    }
    
    private static func renderImage(grid: [String], scale: CGFloat) -> NSImage {
        let height = grid.count
        let width = grid.first?.count ?? 0
        let size = NSSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        
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
                        // Dark stripes / pattern (75% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
                        ctx.fill(pixelRect)
                    case "C":
                        // Main body coat (60% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.60).cgColor)
                        ctx.fill(pixelRect)
                    case "P":
                        // Inner ear & tongue accent (35% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
                        ctx.fill(pixelRect)
                    case "W":
                        // White chest bib highlight (25% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.25).cgColor)
                        ctx.fill(pixelRect)
                    case "Z", "z":
                        // Sleep Zzz (80% opacity)
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
    
    // MARK: - Stage 1: Energetic (20x18) - Golden Ginger Tabby (Reference Cat 1)
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
            ".BCCCBCBCBCBCCCBB...",
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
            ".BCCCBCBCBCBCCCBB...",
            "..BCCBCBCBCBCCB.....",
            "...BBB.BBB.BBB......",
            ".....BBB.BBB........"
        ]
    ]
    
    // MARK: - Stage 2: Content (20x18) - British Shorthair Blue/Gray (Reference Cat 2)
    private static let contentGrids: [[String]] = [
        [
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BSCB",
            "..BCCWCCCCCWCCBBCSB.",
            ".BCCCCWCCCWCCCCBSB..",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBSB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBCCWCCBCCCBSB..",
            ".BCCCBCBCBCBCCCBB...",
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
            "..BCCWCCCCCWCCBBCB..",
            ".BCCCCWCCCWCCCCBCB..",
            ".BCCCCWWWWWCCCCBSB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBSB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBCCWCCBCCCBSB..",
            ".BCCCBCBCBCBCCCBB...",
            "..BCCBCBCBCBCCB.....",
            "...BBB.BBB.BBB......",
            ".....BBB.BBB........"
        ]
    ]
    
    // MARK: - Stage 3: Tired (20x18) - Drowsy White/Ivory Cat with Drifting Zzz (Reference Cat 3)
    private static let tiredGrids: [[String]] = [
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            ".....B.....B...ZZZZ.",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BCCB",
            "..BCCWCCCCCWCCBBCCB.",
            ".BCCCCWCCCWCCCCBCB..",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBCCWCCBCCCBCB..",
            ".BCCCBCBCBCBCCCBB...",
            "...BBB.BBB.BBB......"
        ],
        [
            "...............ZZZZ.",
            ".................ZZ.",
            ".....B.....B....ZZ..",
            "....BPB...BPB..ZZZZ.",
            "....BPPBBBPPB..zz...",
            "...BCCCCSCCCCB..z...",
            "...BCBBCCCBBCB.zz...",
            "...BCCCCBCCCCB......",
            "..BCCCCBCBCCCCB..BB.",
            "..BCCWCCCCCWCCB.BCCB",
            ".BCCCCWCCCWCCCCBBCCB",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCBCCWCCBCCCBCB..",
            ".BCCCBCBCBCBCCCBB...",
            "..BCCBCBCBCBCCB.....",
            "...BBB.BBB.BBB......"
        ]
    ]
    
    // MARK: - Stage 4: Melting (20x18) - Calico Mochi with Blep Tongue (Reference Cat 4)
    private static let meltingGrids: [[String]] = [
        [
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BCCB",
            "..BCCCBPPBCCCCBBCCB.",
            ".BCCCCWPPWCCCCBCB...",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCCCCCCCCBBCB..",
            ".BCCCCCCCCCCCCCCBB..",
            ".BCCCCCCCCCCCCCCCB..",
            "..BBBBBBBBBBBBBBB..."
        ],
        [
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB..BB..",
            "..BCCCCBCBCCCCB.BCCB",
            "..BCCCBPPBCCCCBBCCB.",
            ".BCCCCWPPWCCCCBCB...",
            ".BCCCCWWWWWCCCCBCB..",
            ".BCCCCCWWWCCCCCBCB..",
            ".BCCCCCCCCCCCCBBCB..",
            ".BCCCCCCCCCCCCCCBB..",
            ".BCCCCCCCCCCCCCCCB..",
            "..BBBBBBBBBBBBBBB..."
        ]
    ]
    
    // MARK: - Stage 5: Liquid (20x18) - Siamese Flat Puddle Loaf (Reference Cat 6)
    private static let liquidGrids: [[String]] = [
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            "....................",
            "....................",
            "....................",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BCCB",
            ".BCCCCCCCCCCCCBBCB..",
            ".BCCCCCCCCCCCCCCBB..",
            ".BCCCCCCCCCCCCCCCB..",
            "..BBBBBBBBBBBBBBB..."
        ],
        [
            "...............ZZZZ.",
            ".................ZZ.",
            "................ZZ..",
            "...............ZZZZ.",
            ".............zz.....",
            "..............z.....",
            ".............zz.....",
            ".....B.....B........",
            "....BPB...BPB.......",
            "....BPPBBBPPB.......",
            "...BCCCCSCCCCB......",
            "...BCBBCCCBBCB......",
            "...BCCCCBCCCCB...BB.",
            "..BCCCCBCBCCCCB.BCCB",
            ".BCCCCCCCCCCCCBBCB..",
            ".BCCCCCCCCCCCCCCBB..",
            ".BCCCCCCCCCCCCCCCB..",
            "..BBBBBBBBBBBBBBB..."
        ]
    ]
}
