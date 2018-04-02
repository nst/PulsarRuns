#!/usr/bin/env python

import os
import json
import cairo

ROOT_DIR = "/Users/nst/Library/Application Support/PulsarRuns"
PULSAR_DIR = "pulsar"
PULSAR_PATH = os.path.sep.join([ROOT_DIR, PULSAR_DIR])

CANVAS_W = 1000
CANVAS_H = 4200

MAX_ACTIVITY_H = 100.0

TOP_MARGIN_H = 50.0

LEFT_MARGIN_W = 50.0
LEFT_FLAT_ZONE_W = 50.0

RIGHT_MARGIN_W = 50.0
RIGHT_FLAT_ZONE_W = 50.0
RIGHT_TEXT_ZONE_W = 460.0

ACTIVITIES_OFFSET_H = 20.0

GRAY_COLOR = (0.5, 0.5, 0.5)
WHITE_COLOR = (1,1,1)
BLACK_COLOR = (0,0,0)
CLEAR_COLOR = (0,0,0,0) # transparent black

def sort_activities(a):
    low = a["lowest_relative_altitude"]
    high = a["highest_relative_altitude"]
    
    return low if abs(low) > high else high

if __name__ == "__main__":

    # check that relevant directories exist
    
    for p in [ROOT_DIR, PULSAR_PATH]:
        if not os.path.exists(p):
            print("--" + p + "is missing")
            sys.exit(1)

    # read athlete
    
    with open(os.path.sep.join([ROOT_DIR, "athlete.json"])) as f:    
        athlete = json.load(f)
    
    # read activities in /pulsar/ directory
    
    activities_paths = [os.path.sep.join([PULSAR_PATH, f]) for f in os.listdir(PULSAR_PATH) if os.path.splitext(f)[1] == ".json"]

    activities = []
    
    for p in activities_paths:
        with open(p) as f:    
            a = json.load(f)
            activities.append(a)
    
    max_distance = max([a["distances"][-1] for a in activities])
        
    max_altitude_delta = max([max(a["relative_altitudes"]) for a in activities])
    
    activities.sort(key=sort_activities, reverse=True)
        
    img = cairo.ImageSurface(cairo.FORMAT_ARGB32, CANVAS_W, CANVAS_H)
    c = cairo.Context(img)
    
    c.set_source_rgb(*BLACK_COLOR)
    c.rectangle(0, 0, CANVAS_W, CANVAS_H)
    c.fill()
    
    for i,a in enumerate(activities):
        
        # 1. compute base Y
        
        base_y = TOP_MARGIN_H + MAX_ACTIVITY_H + ACTIVITIES_OFFSET_H * i
        
        # 2. draw left gray line
    
        c.set_source_rgb(*GRAY_COLOR)
        
        c.move_to(LEFT_MARGIN_W, base_y)
        c.line_to(LEFT_MARGIN_W+LEFT_FLAT_ZONE_W, base_y)
        c.stroke()
        
        # 3. draw run profile in white
    
        low = a["lowest_relative_altitude"]
        high = a["highest_relative_altitude"]
        
        c.move_to(LEFT_MARGIN_W + LEFT_FLAT_ZONE_W, base_y)
        
        first_altitude = a["relative_altitudes"][0]
        
        last_x = 0.0
        
        for j,rel_alt in enumerate(a["relative_altitudes"]):

            y = base_y - MAX_ACTIVITY_H * (rel_alt / max_altitude_delta)

            x_ratio = a["distances"][j] / max_distance      
             
            x = LEFT_MARGIN_W + LEFT_FLAT_ZONE_W + (CANVAS_W - LEFT_MARGIN_W - RIGHT_MARGIN_W - LEFT_FLAT_ZONE_W - RIGHT_FLAT_ZONE_W - RIGHT_TEXT_ZONE_W) * x_ratio
            last_x = x
            
            c.line_to(x,y)
        
        profile_is_more_down = abs(low) > high
        fill_color = CLEAR_COLOR if profile_is_more_down else BLACK_COLOR
        c.set_source_rgba(*fill_color)
        c.fill_preserve()
        
        c.set_source_rgb(*WHITE_COLOR)
        c.stroke()
        
        # 4. draw right gray line
        
        c.set_source_rgb(*GRAY_COLOR)

        c.move_to(last_x, base_y)
        c.line_to(CANVAS_W-RIGHT_MARGIN_W-RIGHT_TEXT_ZONE_W, base_y)
        c.stroke()
        
        # 5. draw run name
        
        font_size = 16
        
        c.set_source_rgb(*GRAY_COLOR)
        c.set_font_size(font_size)

        c.select_font_face("Helvetica", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
        c.move_to(1000 - RIGHT_MARGIN_W-RIGHT_TEXT_ZONE_W + 16, base_y)
        c.show_text(a["name"])
    
    # 6. draw athlete name
    
    c.move_to(LEFT_MARGIN_W, TOP_MARGIN_H + len(activities) * ACTIVITIES_OFFSET_H + MAX_ACTIVITY_H + 80)

    font_size = 72

    c.select_font_face("Helvetica", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    c.set_source_rgb(*WHITE_COLOR)
    c.set_font_size(font_size)
    c.show_text(athlete["firstname"] + " " + athlete["lastname"])
        
    FILE_NAME = "pulsar_runs.png"
    img.write_to_png(FILE_NAME)
    
    os.system("open -a Safari %s" % FILE_NAME)
