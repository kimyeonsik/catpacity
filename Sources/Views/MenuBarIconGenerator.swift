import AppKit

public class MenuBarIconGenerator {
    
    public static func generateIcon(for stage: CatStage) -> NSImage {
        let size = NSSize(width: 24, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            
            switch stage {
            case .energetic:
                drawEnergeticCat(rect: rect)
            case .content:
                drawContentCat(rect: rect)
            case .tired:
                drawTiredCat(rect: rect)
            case .melting:
                drawMeltingCat(rect: rect)
            case .liquid:
                drawLiquidCat(rect: rect)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
    
    // MARK: - Stage 1: Energetic (Sitting tall, ears up, tail curled high)
    private static func drawEnergeticCat(rect: NSRect) {
        // Body (compact upright oval)
        let bodyPath = NSBezierPath(ovalIn: NSRect(x: 4, y: 1, width: 12, height: 9))
        bodyPath.fill()
        
        // Head (round, positioned up)
        let headPath = NSBezierPath(ovalIn: NSRect(x: 5, y: 7, width: 10, height: 9))
        headPath.fill()
        
        // Left Ear (sharp up)
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 6, y: 14))
        leftEar.line(to: NSPoint(x: 7.5, y: 18))
        leftEar.line(to: NSPoint(x: 10, y: 14.5))
        leftEar.close()
        leftEar.fill()
        
        // Right Ear (sharp up)
        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 10, y: 14.5))
        rightEar.line(to: NSPoint(x: 12.5, y: 18))
        rightEar.line(to: NSPoint(x: 14, y: 14))
        rightEar.close()
        rightEar.fill()
        
        // Tail (cheerful curved arc up)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 15, y: 4))
        tail.curve(to: NSPoint(x: 21, y: 13),
                   controlPoint1: NSPoint(x: 19, y: 5),
                   controlPoint2: NSPoint(x: 22, y: 9))
        tail.lineWidth = 1.8
        tail.lineCapStyle = .round
        tail.stroke()
        
        // Eyes (clear punch out)
        NSGraphicsContext.current?.compositingOperation = .clear
        let eyeL = NSBezierPath(ovalIn: NSRect(x: 7.5, y: 11, width: 1.5, height: 2))
        let eyeR = NSBezierPath(ovalIn: NSRect(x: 11, y: 11, width: 1.5, height: 2))
        eyeL.fill()
        eyeR.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
    
    // MARK: - Stage 2: Content (Loaf position, ears relaxed, happy squint)
    private static func drawContentCat(rect: NSRect) {
        // Body (tucked loaf oval)
        let bodyPath = NSBezierPath(ovalIn: NSRect(x: 3, y: 1, width: 14, height: 8))
        bodyPath.fill()
        
        // Head (slightly lower)
        let headPath = NSBezierPath(ovalIn: NSRect(x: 4, y: 5, width: 9, height: 8))
        headPath.fill()
        
        // Ears (slightly tilted out)
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 4.5, y: 11))
        leftEar.line(to: NSPoint(x: 5, y: 15))
        leftEar.line(to: NSPoint(x: 8, y: 12))
        leftEar.close()
        leftEar.fill()
        
        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 8.5, y: 12))
        rightEar.line(to: NSPoint(x: 11.5, y: 15))
        rightEar.line(to: NSPoint(x: 12.5, y: 11))
        rightEar.close()
        rightEar.fill()
        
        // Tail (resting low)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 16, y: 3))
        tail.curve(to: NSPoint(x: 20, y: 7),
                   controlPoint1: NSPoint(x: 18, y: 2),
                   controlPoint2: NSPoint(x: 21, y: 5))
        tail.lineWidth = 1.7
        tail.lineCapStyle = .round
        tail.stroke()
        
        // Happy squint eyes (^ ^)
        NSGraphicsContext.current?.compositingOperation = .clear
        let eyeLine = NSBezierPath()
        eyeLine.move(to: NSPoint(x: 6, y: 9))
        eyeLine.line(to: NSPoint(x: 7.5, y: 10))
        eyeLine.line(to: NSPoint(x: 9, y: 9))
        eyeLine.lineWidth = 1.0
        eyeLine.stroke()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
    
    // MARK: - Stage 3: Tired (Slumping, ears sideways, sleepy eyes)
    private static func drawTiredCat(rect: NSRect) {
        // Body (slouching down)
        let bodyPath = NSBezierPath(ovalIn: NSRect(x: 3, y: 1, width: 15, height: 6.5))
        bodyPath.fill()
        
        // Head (dipping forward)
        let headPath = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 8.5, height: 7))
        headPath.fill()
        
        // Left Ear (drooping side)
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 3, y: 8))
        leftEar.line(to: NSPoint(x: 2.5, y: 12))
        leftEar.line(to: NSPoint(x: 6, y: 9.5))
        leftEar.close()
        leftEar.fill()
        
        // Right Ear (drooping)
        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 7, y: 9.5))
        rightEar.line(to: NSPoint(x: 10.5, y: 12))
        rightEar.line(to: NSPoint(x: 11, y: 8))
        rightEar.close()
        rightEar.fill()
        
        // Tail (drooping flat on floor)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 17, y: 2))
        tail.line(to: NSPoint(x: 21, y: 2))
        tail.lineWidth = 1.6
        tail.lineCapStyle = .round
        tail.stroke()
        
        // Sleepy flat eyes (- -)
        NSGraphicsContext.current?.compositingOperation = .clear
        let eyeL = NSBezierPath(rect: NSRect(x: 4.5, y: 6.5, width: 2, height: 1))
        let eyeR = NSBezierPath(rect: NSRect(x: 8, y: 6.5, width: 2, height: 1))
        eyeL.fill()
        eyeR.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
    
    // MARK: - Stage 4: Melting (Stretching out, chin on ground, droop)
    private static func drawMeltingCat(rect: NSRect) {
        // Melty flat elongated body
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 2, y: 1))
        body.curve(to: NSPoint(x: 19, y: 1),
                   controlPoint1: NSPoint(x: 5, y: 5),
                   controlPoint2: NSPoint(x: 15, y: 5))
        body.curve(to: NSPoint(x: 2, y: 1),
                   controlPoint1: NSPoint(x: 18, y: 0.5),
                   controlPoint2: NSPoint(x: 4, y: 0.5))
        body.close()
        body.fill()
        
        // Flat head rested on paws
        let head = NSBezierPath(ovalIn: NSRect(x: 2, y: 1, width: 9, height: 5))
        head.fill()
        
        // Flattened ears (horizontal)
        let earL = NSBezierPath()
        earL.move(to: NSPoint(x: 2, y: 5))
        earL.line(to: NSPoint(x: 0, y: 6.5))
        earL.line(to: NSPoint(x: 4, y: 6))
        earL.close()
        earL.fill()
        
        let earR = NSBezierPath()
        earR.move(to: NSPoint(x: 6, y: 6))
        earR.line(to: NSPoint(x: 10, y: 6.5))
        earR.line(to: NSPoint(x: 9, y: 5))
        earR.close()
        earR.fill()
        
        // Tail trailing limply
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 18, y: 1.5))
        tail.line(to: NSPoint(x: 22.5, y: 1))
        tail.lineWidth = 1.4
        tail.lineCapStyle = .round
        tail.stroke()
        
        // Tired slits
        NSGraphicsContext.current?.compositingOperation = .clear
        let eye = NSBezierPath(rect: NSRect(x: 4, y: 3.5, width: 4.5, height: 0.8))
        eye.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
    
    // MARK: - Stage 5: Liquid / Fully Flat (Pancake puddle, x x sleepy eyes)
    private static func drawLiquidCat(rect: NSRect) {
        // Complete liquid puddle (고양이는 액체)
        let puddle = NSBezierPath()
        puddle.move(to: NSPoint(x: 1, y: 1))
        puddle.curve(to: NSPoint(x: 22, y: 1),
                     controlPoint1: NSPoint(x: 3, y: 3.8),
                     controlPoint2: NSPoint(x: 18, y: 3.8))
        puddle.curve(to: NSPoint(x: 1, y: 1),
                     controlPoint1: NSPoint(x: 20, y: 0.2),
                     controlPoint2: NSPoint(x: 3, y: 0.2))
        puddle.close()
        puddle.fill()
        
        // Tiny flopped ears on the puddle surface
        let ear1 = NSBezierPath()
        ear1.move(to: NSPoint(x: 4, y: 3))
        ear1.line(to: NSPoint(x: 2, y: 4.5))
        ear1.line(to: NSPoint(x: 5.5, y: 3.5))
        ear1.close()
        ear1.fill()
        
        let ear2 = NSBezierPath()
        ear2.move(to: NSPoint(x: 8, y: 3.5))
        ear2.line(to: NSPoint(x: 11, y: 4.5))
        ear2.line(to: NSPoint(x: 10, y: 3))
        ear2.close()
        ear2.fill()
        
        // Soft snooze indicator or flat closed eyes
        NSGraphicsContext.current?.compositingOperation = .clear
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 5, y: 2))
        eye.line(to: NSPoint(x: 8.5, y: 2))
        eye.lineWidth = 0.9
        eye.stroke()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
}
