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
                    case "B", "-", "x":
                        // Crisp solid black outline/features (becomes 100% white in dark mode, black in light mode)
                        ctx.setFillColor(NSColor.black.cgColor)
                        ctx.fill(pixelRect)
                    case "C":
                        // Body fur texture (soft 65% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
                        ctx.fill(pixelRect)
                    case "H":
                        // Inner ear & belly highlight (delicate 35% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
                        ctx.fill(pixelRect)
                    case "P":
                        // Pink accents (30% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
                        ctx.fill(pixelRect)
                    case "W":
                        // Sparkles & catchlights (90% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.90).cgColor)
                        ctx.fill(pixelRect)
                    case "Z", "z":
                        // Sleep Z / effect (75% opacity)
                        ctx.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
                        ctx.fill(pixelRect)
                    default:
                        // Transparent cutout: "." background, "E" eyes
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
    
    // MARK: - Stage 1: Energetic (28x18) - Delicate upright cat, perky ears, wagging tail, sparkle
    private static let energeticGrids: [[String]] = [
        [
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB....WW.....",
            "..BCHCB.....BCHCB...WWWW....",
            ".BCHHCB.....BCHHCB...WW.....",
            ".BCCCCCBBBBBCCCCCB..........",
            ".BCCCCCCCCCCCCCCCB.......BB.",
            ".BCCEECCCCCCCEECCB......BCCB",
            ".BCCWECCCCCCCEWCCB.....BCCCB",
            ".BCCEECCCCCCCEECCB....BCCCCB",
            ".BCPPCCCCPCCCCPPCB...BCCCCCB",
            ".BCCCCCCB.BCCCCCCB...BCCCCB.",
            "..BCCCCCCCCCCCCCB...BCCCCB..",
            "...BCCCCCCCCCCCBBBBBCCCCB...",
            "...BCCCCCCCCCCCCCCCCCCCB....",
            "...BCCCCBCCCCBCCCCCCCCCB....",
            "...BCCCCBCCCCBCCCCCCCCCB....",
            "....BBBB..BBBB..BBBBBBB....."
        ],
        [
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB...........",
            "..BCHCB.....BCHCB....WW.....",
            ".BCHHCB.....BCHHCB..WWWW....",
            ".BCCCCCBBBBBCCCCCB...WW.....",
            ".BCCCCCCCCCCCCCCCB......BBB.",
            ".BCCEECCCCCCCEECCB.....BCCCB",
            ".BCCWECCCCCCCEWCCB....BCCCCB",
            ".BCCEECCCCCCCEECCB...BCCCCB.",
            ".BCPPCCCCPCCCCPPCB..BCCCCB..",
            ".BCCCCCCB.BCCCCCCB.BCCCCB...",
            "..BCCCCCCCCCCCCCBBCCCCB.....",
            "...BCCCCCCCCCCCBBCCCCB......",
            "...BCCCCCCCCCCCCCCCCB.......",
            "...BCCCCBCCCCBCCCCB.........",
            "...BCCCCBCCCCBCCCCB.........",
            "....BBBB..BBBB..BB.........."
        ]
    ]
    
    // MARK: - Stage 2: Content (28x18) - Delicate loaf cat, tucked paws, peaceful crescent eyes
    private static let contentGrids: [[String]] = [
        [
            "............................",
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB...........",
            "..BCHCB.....BCHCB...........",
            ".BCHHCB.....BCHHCB..........",
            ".BCCCCCBBBBBCCCCCB..........",
            ".BCCCCCCCCCCCCCCCB..........",
            ".BCCCCCCCCCCCCCCCB..........",
            ".BCC--CCCCCC--CCCB..........",
            ".BCPPCCCCPCCCCPPCB...BBBB...",
            ".BCCCCCCB.BCCCCCCBBBBCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCHHCCCCCHHCCCCCCCCCCCCB.",
            ".BCCCHHCCCCCHHCCCCCCCCCCCCB.",
            "..BBBBBBBBBBBBBBBBBBBBBBBB.."
        ],
        [
            "............................",
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB...........",
            "..BCHCB.....BCHCB........BB.",
            ".BCHHCB.....BCHHCB......BCCB",
            ".BCCCCCBBBBBCCCCCB.....BCCCB",
            ".BCCCCCCCCCCCCCCCB....BCCCCB",
            ".BCCCCCCCCCCCCCCCB...BCCCCB.",
            ".BCC--CCCCCC--CCCB..BCCCCB..",
            ".BCPPCCCCPCCCCPPCB.BCCCCB...",
            ".BCCCCCCB.BCCCCCCBBCCCCB....",
            "..BCCCCCCCCCCCCCCCCCCCB.....",
            "..BCCCCCCCCCCCCCCCCCCCCB....",
            ".BCCCCCCCCCCCCCCCCCCCCCCB...",
            ".BCCCHHCCCCCHHCCCCCCCCCCB...",
            ".BCCCHHCCCCCHHCCCCCCCCCCB...",
            "..BBBBBBBBBBBBBBBBBBBBBB...."
        ]
    ]
    
    // MARK: - Stage 3: Tired (28x18) - Slumping cat, heavy sleepy eyes, drifting Zzz
    private static let tiredGrids: [[String]] = [
        [
            "............................",
            "......................ZZZZ..",
            "........................ZZ..",
            ".......................ZZ...",
            "...BB.........BB......ZZZZ..",
            "..BCCB.......BCCB...........",
            "..BCHCB.....BCHCB...........",
            ".BCHHCB.....BCHHCB..........",
            ".BCCCCCBBBBBCCCCCB..........",
            ".BCCCCCCCCCCCCCCCB..........",
            ".BCC--CCCCCC--CCCB..........",
            ".BCPPCCCCPCCCCPPCB...BBBB...",
            ".BCCCCCCB.BCCCCCCBBBBCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCHHCCCCCHHCCCCCCCCCCCCB.",
            "..BBBBBBBBBBBBBBBBBBBBBBBB.."
        ],
        [
            "......................ZZZZ..",
            "........................ZZ..",
            ".......................ZZ...",
            "......................ZZZZ..",
            "...BB.........BB...zzz......",
            "..BCCB.......BCCB....z......",
            "..BCHCB.....BCHCB...z.......",
            ".BCHHCB.....BCHHCB.zzz......",
            ".BCCCCCBBBBBCCCCCB..........",
            ".BCCCCCCCCCCCCCCCB..........",
            ".BCC--CCCCCC--CCCB..........",
            ".BCPPCCCCPCCCCPPCB...BBBB...",
            ".BCCCCCCB.BCCCCCCBBBBCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCB..",
            "..BCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BCCCHHCCCCCHHCCCCCCCCCCCCB.",
            "..BBBBBBBBBBBBBBBBBBBBBBBB.."
        ]
    ]
    
    // MARK: - Stage 4: Melting (28x18) - Flat melting mochi cat, blep tongue, sweat drop
    private static let meltingGrids: [[String]] = [
        [
            "............................",
            "............................",
            "............................",
            "............................",
            "...................WW.......",
            "....BB.......BB...WWWW......",
            "...BCCB.....BCCB...WW.......",
            "..BCCCCBBBBBCCCCB..W........",
            ".BCCCCCCCCCCCCCCCB..........",
            ".BCCxxCCCCCCxxCCCB..........",
            ".BCPPCCCCPCCCCPCCBBBBBB.....",
            ".BCCCCCCPPPCCCCCCCCCCCCB....",
            ".BCCCCCCCCCCCCCCCCCCCCCCB...",
            "BCCCCCCCCCCCCCCCCCCCCCCCCB..",
            "BCCCCCCCCCCCCCCCCCCCCCCCCB..",
            "BCCCHHHCCCCCHHHCCCCCCCCCCB..",
            ".BCCCCCCCCCCCCCCCCCCCCCCB...",
            "..BBBBBBBBBBBBBBBBBBBBBB...."
        ],
        [
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            "....BB.......BB....WW.......",
            "...BCCB.....BCCB..WWWW......",
            "..BCCCCBBBBBCCCCB..WW.......",
            ".BCCCCCCCCCCCCCCCB.W........",
            ".BCC--CCCCCC--CCCB..........",
            ".BCPPCCCCPCCCCPCCBBBBBB.....",
            ".BCCCCCCPPPCCCCCCCCCCCCB....",
            ".BCCCCCCCCCCCCCCCCCCCCCCB...",
            "BCCCCCCCCCCCCCCCCCCCCCCCCB..",
            "BCCCCCCCCCCCCCCCCCCCCCCCCB..",
            "BCCCHHHCCCCCHHHCCCCCCCCCCB..",
            ".BCCCCCCCCCCCCCCCCCCCCCCB...",
            "..BBBBBBBBBBBBBBBBBBBBBB...."
        ]
    ]
    
    // MARK: - Stage 5: Liquid (28x18) - Fully melted flat puddle, peaceful snore
    private static let liquidGrids: [[String]] = [
        [
            "............................",
            "....................ZZZZ....",
            "......................ZZ....",
            ".....................ZZ.....",
            "....................ZZZZ....",
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB...........",
            ".BCCCCBBBBBCCCCB............",
            ".BCC--CCCCCC--CB............",
            ".BCPPCCCCPCCCCPCCBBBBBBBBB..",
            "BCCCCCCCCPPPCCCCCCCCCCCCCCB.",
            "BCCCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BBBBBBBBBBBBBBBBBBBBBBBBB.."
        ],
        [
            "....................ZZZZ....",
            "......................ZZ....",
            ".....................ZZ.....",
            "....................ZZZZ....",
            "..................zzz.......",
            "....................z.......",
            "...................z........",
            "..................zzz.......",
            "............................",
            "............................",
            "...BB.........BB............",
            "..BCCB.......BCCB...........",
            ".BCCCCBBBBBCCCCB............",
            ".BCCxxCCCCCCxxCB............",
            ".BCPPCCCCPCCCCPCCBBBBBBBBB..",
            "BCCCCCCCCPPPCCCCCCCCCCCCCCB.",
            "BCCCCCCCCCCCCCCCCCCCCCCCCCB.",
            ".BBBBBBBBBBBBBBBBBBBBBBBBB.."
        ]
    ]
}
