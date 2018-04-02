//
//  ShapefileView.swift
//  Shapefile
//
//  Created by nst on 26/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

// idea from http://www.xavigimenez.net/blog/2015/05/plotting-my-strava-running-activity-as-a-pulsar-plot/

class RunningView : CanvasView {
    
    var activities : [[String:AnyObject]] = []
    var athlete : [String:AnyObject] = [:]
    var maxDistance = 0.0
    var maxAltitudeDelta = 0.0
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(frame frameRect: NSRect, activities:[[String:AnyObject]], athlete:[String:AnyObject], activityIDsToBeMerged:[[Int]]) {
        super.init(frame:frameRect)
        self.activities = activities
        self.athlete = athlete
        
        self.updateActivitiesByMergingIDs(activityIDsToBeMerged:activityIDsToBeMerged)
        
        let optionalMaxDistance = activities.map{ $0["distance"] as? Double }.flatMap{ $0 }.max()
        
        guard let existingMaxDistance = optionalMaxDistance else {
            fatalError("ensure you've downloaded athlete first")
        }
        
        maxDistance = existingMaxDistance
        
        //
        
        let altitudesDelta : [Double] = activities.map {
            guard let altitudes = $0["altitude_points"] as? [Double] else { assertionFailure(); return 0.0 }
            guard let altitudeMin = altitudes.min() else { assertionFailure(); return 0.0 }
            guard let altitudeMax = altitudes.max() else { assertionFailure(); return 0.0 }
            return altitudeMax - altitudeMin
        }

        guard let existingMaxAltitudeDelta = altitudesDelta.max() else {
            fatalError("ensure you've downloaded athlete first")
        }
        
        maxAltitudeDelta = existingMaxAltitudeDelta
    }
    
    func updateActivitiesByMergingIDs(activityIDsToBeMerged:[[Int]]) {
        // for IDs to be merged, update 'altitude_points' and 'distance_points'
        for ids in activityIDsToBeMerged {
            let parentID = ids[0]
            let childrenID = ids[1..<ids.count]
            guard var p = self.activity(id: parentID) else { fatalError() }
            guard var pAltitudePoints = p["altitude_points"] as? [Double] else { fatalError() }
            guard var pDistancePoints = p["distance_points"] as? [Double] else { fatalError() }
            for childID in childrenID {
                guard let lastDistance = pDistancePoints.last else { fatalError() }
                guard let c = self.activity(id: childID) else { continue }
                guard let cAltitudePoints = c["altitude_points"] as? [Double] else { fatalError() }
                guard let cDistancePoints = c["distance_points"] as? [Double] else { fatalError() }
                pAltitudePoints += cAltitudePoints
                pDistancePoints += cDistancePoints.map { lastDistance + $0 }
                removeActivity(id:childID)
            }
            p["altitude_points"] = pAltitudePoints as AnyObject
            p["distance_points"] = pDistancePoints as AnyObject
            removeActivity(id:ids[0])
            self.activities.append(p)
        }
    }
    
    func activity(id:Int) -> [String:AnyObject]? {
        return activities.filter { $0["id"] as? Int == id }.first
    }
    
    func removeActivity(id:Int) {
        guard let a = activity(id: id) else { fatalError() }
        
        for (i,o) in activities.enumerated() {
            guard let oID = o["id"] as? Int else { fatalError() }
            guard let aID = a["id"] as? Int else { fatalError() }
            if oID == aID {
                self.activities.remove(at: i)
                return
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
        super.draw(dirtyRect)
        
        context.setShouldAntialias(true)
        
        context.saveGState()
        
        // ensure pixel-perfect bitmap
        // context.translate(x: 0.5, y: 0.5)
        
        // makes coordinates start upper left
        context.translateBy(x: 0.0, y: self.bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        NSColor.black.setFill()
        context.fill(dirtyRect)
        
        let MAX_ACTIVITY_H = 100.0
        
        let TOP_MARGIN_H = 50.0
        
        let LEFT_MARGIN_W : CGFloat = 50.0
        let LEFT_FLAT_ZONE_W : CGFloat = 50.0
        
        let RIGHT_MARGIN_W : CGFloat = 50.0
        let RIGHT_FLAT_ZONE_W : CGFloat = 50.0
        let RIGHT_TEXT_ZONE_W : CGFloat = 460.0
        
        let ACTIVITIES_OFFSET_H = 20.0
        
        activities.sort {
            
            guard let low1 = $0["lowest_relative_altitude"] as? Double else { assertionFailure(); return false }
            guard let low2 = $1["lowest_relative_altitude"] as? Double else { assertionFailure(); return false }
            
            guard let high1 = $0["highest_relative_altitude"] as? Double else { assertionFailure(); return false }
            guard let high2 = $1["highest_relative_altitude"] as? Double else { assertionFailure(); return false }
            
            let delta1 = abs(low1) > high1 ? low1 : high1
            let delta2 = abs(low2) > high2 ? low2 : high2
            
            return delta1 > delta2
        }
        
        for (i, activity) in activities.enumerated() {

            guard let altitudes = activity["altitude_points"] as? [Double] else { assertionFailure(); continue }
            guard let distances = activity["distance_points"] as? [Double] else { assertionFailure(); continue }
            
            assert(altitudes.count == distances.count)

            // 1. compute base Y
            
            let baseY = TOP_MARGIN_H + MAX_ACTIVITY_H + ACTIVITIES_OFFSET_H * Double(i)

            // 2. draw left gray line

            NSColor.gray.setStroke()

            let pathLeft = NSBezierPath()
            pathLeft.lineWidth = 2.0
            pathLeft.lineCapStyle = .roundLineCapStyle
            pathLeft.move(to: P(LEFT_MARGIN_W, CGFloat(baseY)))
            pathLeft.line(to: P(CGFloat(LEFT_MARGIN_W+LEFT_FLAT_ZONE_W), CGFloat(baseY)))
            pathLeft.stroke()

            // 3. draw run profile in white

            NSColor.white.setStroke()

            guard let low = activity["lowest_relative_altitude"] as? Double else { assertionFailure(); continue }
            guard let high = activity["highest_relative_altitude"] as? Double else { assertionFailure(); continue }
            let profileIsMoreDown = abs(low) > high
            
            let fillColor = profileIsMoreDown ? NSColor.clear : NSColor.black
            
            fillColor.setFill()
            
            let path = NSBezierPath()
            path.lineWidth = 2.0
            path.lineCapStyle = .roundLineCapStyle
            path.move(to: P(LEFT_MARGIN_W + LEFT_FLAT_ZONE_W, CGFloat(baseY)))
            //            path.line(to: P(CGFloat(LEFT_MARGIN_W+LEFT_FLAT_ZONE_W), CGFloat(baseY)))
            
            guard let firstAltitude = altitudes.first else { assertionFailure(); continue }
            
            var lastX : CGFloat = 0.0
            for (j, altitude) in altitudes.enumerated() {
                
                let altitudeDelta = altitude - firstAltitude
                
                let y = baseY - MAX_ACTIVITY_H * (Double(altitudeDelta) / Double(maxAltitudeDelta))
                
                let xRatio = distances[j] / maxDistance
                let x = LEFT_MARGIN_W + LEFT_FLAT_ZONE_W + (self.frame.width - LEFT_MARGIN_W - RIGHT_MARGIN_W - LEFT_FLAT_ZONE_W - RIGHT_FLAT_ZONE_W - RIGHT_TEXT_ZONE_W) * CGFloat(xRatio)
                lastX = x
                
                path.line(to: P(x,CGFloat(y)))
            }
            
            path.fill()
            path.stroke()
            
            // 4. draw right gray line
            
            NSColor.gray.setStroke()
            
            let pathRight = NSBezierPath()
            pathRight.lineWidth = 2.0
            pathRight.lineCapStyle = .roundLineCapStyle
            pathRight.move(to: P(lastX, CGFloat(baseY)))
            pathRight.line(to: P(self.frame.width-RIGHT_MARGIN_W-RIGHT_TEXT_ZONE_W,CGFloat(baseY)))
            pathRight.stroke()
        
            // 5. draw run name
            
            if let activityName = activity["name"] as? String {
                let fontSize = CGFloat(18)
                let point = P(self.frame.width-RIGHT_MARGIN_W-RIGHT_TEXT_ZONE_W + 16, CGFloat(baseY) - fontSize + 6)
                let font = NSFont(name:"Helvetica", size:fontSize)!
                self.text(activityName, point, font:font, color:NSColor.gray)
            }
        }
        
        // 6. draw athlete name
        
        let drawName = true
        
        if drawName {
            guard let firstName = athlete["firstname"] else { assertionFailure(); return }
            guard let lastName = athlete["lastname"] else { assertionFailure(); return }
            
            let textPoint = NSMakePoint(
                LEFT_MARGIN_W,
                CGFloat(TOP_MARGIN_H) + CGFloat(activities.count) * CGFloat(ACTIVITIES_OFFSET_H) + CGFloat(MAX_ACTIVITY_H) + CGFloat(40))
            
            let font = NSFont(name:"Helvetica", size:72)!
            self.text("\(firstName) \(lastName)", textPoint, font:font, color:NSColor.white)
        }
        
        context.restoreGState()
    }
}
