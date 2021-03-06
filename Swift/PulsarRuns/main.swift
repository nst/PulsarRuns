//
//  main.swift
//  PulsarRuns
//
//  Created by Nicolas Seriot on 28/06/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

let ACCESS_TOKEN = "" // from https://www.strava.com/settings/api

func fetchAthlete(completion: @escaping (([String:AnyObject])->Void)) {
    
    let urlString = "https://www.strava.com/api/v3/athlete?access_token=\(ACCESS_TOKEN)&per_page=200"
    print(urlString)
    
    URLSession.shared.dataTask(with: URL(string: urlString)!) { (data, response, error) in
        guard let existingData = data else { completion([:]); return }
        guard let optionalAthlete = try? JSONSerialization.jsonObject(with: existingData) as? [String:AnyObject] else { completion([:]); return }
        guard let athlete = optionalAthlete else { completion([:]); return }
        
        DispatchQueue.main.async {
            completion(athlete)
        }
        }.resume()
}

func fetchActivities(completion: @escaping (([[String:AnyObject]])->Void)) {
    
    let urlString = "https://www.strava.com/api/v3/activities?access_token=\(ACCESS_TOKEN)&per_page=200"
    print(urlString)
    
    URLSession.shared.dataTask(with: URL(string: urlString)!) { (data, response, error) in
        guard let existingData = data else { completion([]); return }
        guard let optionalActivities = try? JSONSerialization.jsonObject(with: existingData) as? [[String:AnyObject]] else { completion([]); return }
        guard let activities = optionalActivities else { completion([]); return }
        
        DispatchQueue.main.async {
            completion(activities)
        }
        }.resume()
}

func fetchAltitudes(_ id:Int, resolution:String = "medium", completion: @escaping ((_ distancePoints:[Double], _ altitudePoints:[Double])->Void)) {
    
    let urlString = "https://www.strava.com/api/v3/activities/\(id)/streams/altitude?resolution=\(resolution)&access_token=\(ACCESS_TOKEN)"
    print(urlString)
    
    URLSession.shared.dataTask(with: URL(string: urlString)!) { (data, response, error) in
        guard let existingData = data else { completion([], []); return }
        guard let optionalStreams = try? JSONSerialization.jsonObject(with: existingData) as? [[String:AnyObject]] else { completion([], []); return }
        guard let streams = optionalStreams else { completion([], []); return }
        
        guard let distanceStream = streams.filter({ $0["type"] as? String == "distance" }).first else { assertionFailure(); return }
        guard let altitudeStream = streams.filter({ $0["type"] as? String == "altitude" }).first else { assertionFailure(); return }
        
        guard let distancePoints = distanceStream["data"] as? [Double] else { assertionFailure(); return }
        guard let altitudePoints = altitudeStream["data"] as? [Double] else { assertionFailure(); return }
        
        DispatchQueue.main.async {
            completion(distancePoints, altitudePoints)
        }
        }.resume()
}

func downloadAndDumpAthleteAndActivities(dirPath:String, completion: @escaping (()->Void)) {
    
    assert(ACCESS_TOKEN.count > 0, "Get an access token from Strava on https://www.strava.com/settings/api")
    
    fetchActivities { (activities) in
        
        let group = DispatchGroup()
        
        group.enter()
        
        fetchAthlete(completion: { (athlete) in
            
            do {
                let data = try JSONSerialization.data(withJSONObject: athlete, options: [])
                let path = (dirPath as NSString).appendingPathComponent("athlete.json")
                let url = URL(fileURLWithPath: path)
                try data.write(to: url)
                print("-- athlete \(athlete) saved")
            } catch let error {
                print(error)
                print("-- athlete \(athlete) error: \(error)")
            }
            
            group.leave()
        })
        
        for a in activities {
            
            guard let id = a["id"] as? Int else { continue }
            guard let type = a["type"] as? String, type == "Run" else { continue }
            
            var a_augmented = a
            
            group.enter()
            
            fetchAltitudes(id, completion: { (distancePoints, altitudePoints) in
                assert(distancePoints.count == altitudePoints.count)
                
                a_augmented["distance_points"] = distancePoints as AnyObject
                a_augmented["altitude_points"] = altitudePoints as AnyObject
                
                guard let startAltitude = altitudePoints.first else { assertionFailure(); return }
                let altitudesDelta = altitudePoints.map{ $0 - startAltitude }
                
                guard let min = altitudesDelta.min() else { assertionFailure(); return }
                guard let max = altitudesDelta.max() else { assertionFailure(); return }
                
                a_augmented["lowest_relative_altitude"] = min as AnyObject
                a_augmented["highest_relative_altitude"] = max as AnyObject
                
                do {
                    let data = try JSONSerialization.data(withJSONObject: a_augmented, options: [])
                    let path = (dirPath as NSString).appendingPathComponent("\(id).json")
                    let url = URL(fileURLWithPath: path)
                    try data.write(to: url)
                    print("-- \(id) saved")
                } catch let error {
                    print(error)
                    print("-- \(id) error: \(error)")
                }
                
                group.leave()
            })
        }
        
        group.notify(queue: DispatchQueue.main) {
            print("-- dumping activities finished")
            completion()
        }
    }
}

func loadAthleteAndActivities(dirPath:String) -> ([String:AnyObject], [[String:AnyObject]]) {
    
    do {
        let athleteData = try Data(contentsOf: URL(fileURLWithPath: dirPath + "/athlete.json"))
        let optionalAthlete = try JSONSerialization.jsonObject(with: athleteData) as? [String:AnyObject]
        let athlete = optionalAthlete ?? [:]
        
        let url = URL(fileURLWithPath: dirPath)
        let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        
        let activities = urls
            .filter{ $0.pathExtension == "json" }
            .flatMap{ try? Data(contentsOf:$0) }
            .flatMap{ try? JSONSerialization.jsonObject(with: $0) as? [String:AnyObject] }
            .flatMap{ $0 }
            .filter{ return $0["type"] as? String == "Run" || $0["type"] as? String == "Race" }
        
        return (athlete, activities)
    } catch let error as NSError {
        print("-- error", error)
    }
    
    return ([:], [])
}

let download = false // true to download data, then false to draw picture

if download {
    
    downloadAndDumpAthleteAndActivities(dirPath: "/private/tmp") {
        print("-- downloadAndDumpActivities completed")
        exit(0)
    }
    
    RunLoop.current.run()
    
} else {
    let (athlete, activities) = loadAthleteAndActivities(dirPath: "/private/tmp/")
    //print(athlete)
    //print(activities)
    
    // eg [id_1, id_2, id_3] to get only one path for several consecutive ids
    let kvChando = [722892381, 723144918, 723144855]
    let montreuxRochersDeNaye = [628334311, 628519686]
    let martinaux = [691604950, 691722446]
    let thyonDixence = [667441401, 672243034]
    let idsToBeMerged : [[Int]] = [kvChando, montreuxRochersDeNaye, martinaux, thyonDixence]
    
    let view = RunningView(frame: NSMakeRect(0, 0, 1000, 4300), activities:activities, athlete:athlete, activityIDsToBeMerged:idsToBeMerged)
    
    let shortName = athlete["username"] as? String ?? "strava_runs"
    
    //view.savePDF("/tmp/\(shortName).pdf", open:true)
    view.savePNG("/tmp/\(shortName).png", open:true)
}
