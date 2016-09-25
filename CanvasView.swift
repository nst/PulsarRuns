//
//  CanvasView.swift
//  CanvasView
//
//  Created by Nicolas Seriot on 16/06/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

infix operator * { associativity right precedence 155 }

func *(left:CGFloat, right:Int) -> CGFloat
{ return left * CGFloat(right) }

func *(left:Int, right:CGFloat) -> CGFloat
{ return CGFloat(left) * right }

func *(left:CGFloat, right:Double) -> CGFloat
{ return left * CGFloat(right) }

func *(left:Double, right:CGFloat) -> CGFloat
{ return CGFloat(left) * right }

infix operator + { associativity right precedence 145 }

func +(left:CGFloat, right:Int) -> CGFloat
{ return left + CGFloat(right) }

func +(left:Int, right:CGFloat) -> CGFloat
{ return CGFloat(left) + right }

func +(left:CGFloat, right:Double) -> CGFloat
{ return left + CGFloat(right) }

func +(left:Double, right:CGFloat) -> CGFloat
{ return CGFloat(left) + right }

infix operator - { associativity right precedence 145 }

func -(left:CGFloat, right:Int) -> CGFloat
{ return left - CGFloat(right) }

func -(left:Int, right:CGFloat) -> CGFloat
{ return CGFloat(left) - right }

func -(left:CGFloat, right:Double) -> CGFloat
{ return left - CGFloat(right) }

func -(left:Double, right:CGFloat) -> CGFloat
{ return CGFloat(left) - right }

//

func P(_ x:CGFloat, _ y:CGFloat) -> NSPoint {
    return NSMakePoint(x, y)
}

func P(x:Int, _ y:Int) -> NSPoint {
    return NSMakePoint(CGFloat(x), CGFloat(y))
}

func RandomPoint(maxX:Int, maxY:Int) -> NSPoint {
    return P(CGFloat(arc4random_uniform((UInt32(maxX+1)))), CGFloat(arc4random_uniform((UInt32(maxY+1)))))
}

func R(_ x:CGFloat, _ y:CGFloat, _ w:CGFloat, _ h:CGFloat) -> NSRect {
    return NSMakeRect(x, y, w, h)
}

func R(_ x:Int, _ y:Int, _ w:Int, _ h:Int) -> NSRect {
    return NSMakeRect(CGFloat(x), CGFloat(y), CGFloat(w), CGFloat(h))
}

func degreesToRadians(_ x:CGFloat) -> CGFloat {
    return ((CGFloat(M_PI) * x) / 180.0)
}

class CanvasView : NSView {

    var context : CGContext!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        self.context = unsafeBitCast(NSGraphicsContext.current()!.graphicsPort, to:CGContext.self)
    }
    
    func text(_ text:String, _ p:NSPoint, rotationRadians:CGFloat?, font : NSFont = NSFont(name: "Monaco", size: 10)!, color : NSColor = NSColor.black) {
        
        let attr = [
            NSFontAttributeName:font,
            NSForegroundColorAttributeName:color
        ]
        
        context.saveGState()
        
        if let radians = rotationRadians {
            context.translateBy(x: p.x, y: p.y)
            context.rotate(by: radians)
            context.translateBy(x: -p.x, y: -p.y)
        }
        
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: (-2.0 * p.y) - font.pointSize)
        
        text.draw(at: p, withAttributes: attr)
        
        context.restoreGState()
    }
    
    func text(_ text:String, _ p:NSPoint, rotationDegrees degrees:CGFloat = 0.0, font : NSFont = NSFont(name: "Monaco", size: 10)!, color : NSColor = NSColor.black) {
        self.text(text, p, rotationRadians: degreesToRadians(degrees), font: font, color: color)
    }
    
    func rectangle(rect:NSRect, stroke stroke_:NSColor? = NSColor.black, fill fill_:NSColor? = nil) {
        
        let stroke = stroke_
        let fill = fill_
        
        context.saveGState()
        
        if let existingFillColor = fill {
            existingFillColor.setFill()
            NSBezierPath.fill(rect)
        }
        
        if let existingStrokeColor = stroke {
            existingStrokeColor.setStroke()
            NSBezierPath.stroke(rect)
        }
        
        context.restoreGState()
    }
    
    func polygon(points:[NSPoint], stroke stroke_:NSColor? = NSColor.black, lineWidth:CGFloat=1.0, fill fill_:NSColor? = nil) {
        
        guard points.count >= 3 else {
            assertionFailure("at least 3 points are needed")
            return
        }
        
        context.saveGState()
        
        let path = NSBezierPath()
        
        path.move(to:points[0])
        
        for i in 1..<points.count {
            path.line(to:points[i])
        }
        
        if let existingFillColor = fill_ {
            existingFillColor.setFill()
            path.fill()
        }
        
        path.close()
        
        if let existingStrokeColor = stroke_ {
            existingStrokeColor.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
        
        context.restoreGState()
    }
    
    func savePDF(_ path:String, open:Bool = false) {
        let pdfData = self.dataWithPDF(inside: self.frame)
        do {
            try pdfData.write(to: NSURL.fileURL(withPath: path))
            if open { NSWorkspace.shared().openFile(path) }
        } catch let e as NSError {
            Swift.print(e)
        }
        
    }
    
    func savePNG(_ path:String, open:Bool = false) {
        
        guard let bitmap = self.bitmapImageRepForCachingDisplay(in: self.bounds) else { assertionFailure(); return }
        self.cacheDisplay(in: self.bounds, to: bitmap)
        
        guard let pngData = bitmap.representation(using: .PNG, properties: [:]) else { assertionFailure(); return }
        
        do {
            try pngData.write(to: NSURL.fileURL(withPath: path))
            if open { NSWorkspace.shared().openFile(path) }
        } catch let e as NSError {
            Swift.print(e)
        }
    }
}
