#!/usr/bin/env python

import requests
import os
import json
import sys

ACCESS_TOKEN = ""
ROOT_DIR = os.path.expanduser("~/Library/Application Support/PulsarRuns")
STRAVA_DIR = "strava"
PULSAR_DIR = "pulsar"

FORCE_REFRESH_ACTIVITIES = False

kv_chando = [722892381, 723144918, 723144855]
montreux_rochers_de_naye = [628334311, 628519686]
martinaux = [691604950, 691722446]
thyon_dixence = [667441401, 672243034]

activities_to_be_merged = [kv_chando, montreux_rochers_de_naye, martinaux, thyon_dixence]

def read_json_file_with_cache(path, url=None, force_download=False):
    
    full_path = os.path.sep.join([ROOT_DIR, path])
    
    if os.path.exists(full_path) and force_download == False:
        print "-- read", path
        with open(full_path) as f:    
            return json.load(f)

    if not url:
        print "-- cannot download", path
        return None

    print "-- download", path
    activities = requests.get(url).json()
    with open(full_path, 'w') as outfile:
        print "-- save", path
        json.dump(activities, outfile)
    
    return activities

def build_pr_activity_if_needed(a):
    # reads activity from /strava/ and writes updated activity in /pulsar/
    
    filename = "%d.json" % a["id"]
    path_in = os.path.sep.join([ROOT_DIR, STRAVA_DIR, filename])
    path_out = os.path.sep.join([ROOT_DIR, PULSAR_DIR, filename])

    if os.path.exists(path_out):
        print "-- read", path_out
        with open(path_out) as f:    
            return json.load(f)
    
    streams = []
    if not os.path.exists(path_in):
        print "-- cannot read", path_in
        return None
    
    print "-- read", path_in
    with open(path_in) as f:    
        streams = json.load(f)
    
    if a["type"] not in ["Run", "Race"]:
        print "-- skip activity type", a["type"]
        return None
    
    d = {}
    d["id"] = a["id"]
    d["name"] = a["name"]
    d["distances"] = [s["data"] for s in streams if s["type"] == "distance"][0]
    d["altitudes"] = [s["data"] for s in streams if s["type"] == "altitude"][0]

    d2 = compute_relative_altitudes(d)
    d.update(d2)

    print "-- save", path_out
    with open(path_out, 'w') as f:
        json.dump(d, f)

    return d

def compute_relative_altitudes(d_original):
    
    altitudes = d_original["altitudes"]

    d = {}
    d["relative_altitudes"] = [alt - altitudes[0] for alt in altitudes]
    d["lowest_relative_altitude"] = min(d["relative_altitudes"])
    d["highest_relative_altitude"] = max(d["relative_altitudes"])
    d["abs_max_delta"] = max(abs(d["lowest_relative_altitude"]), abs(d["highest_relative_altitude"]))
    return d

def merge_activities(ids_to_be_merged):    

    # append children distances and altitudes to parent activity, update parent, delete children
    
    for ids in ids_to_be_merged:
        print "-- merge", ids

        # read parent
        
        parent_path = os.path.sep.join([PULSAR_DIR, "%d.json" % ids[0]])
        parent_full_path = os.path.sep.join([ROOT_DIR, parent_path])
    
        a = read_json_file_with_cache(parent_path)

        was_already_merged = "was_already_merged" in a.keys()

        distances = a["distances"]
        altitudes = a["altitudes"]
        
        # read children

        for child_id in ids[1:]:

            child_path = os.path.sep.join([PULSAR_DIR, "%d.json" % child_id])
            child_full_path = os.path.sep.join([ROOT_DIR, child_path])
        
            if not was_already_merged:

                c = read_json_file_with_cache(child_path, None)

                last_distance = distances[-1]
                
                distances += [last_distance + dist for dist in c["distances"]]
                altitudes += c["altitudes"]

                a["was_already_merged"] = True
            
            print "-- delete", child_full_path
            os.remove(child_full_path)

        a["distances"] = distances
        a["altitudes"] = altitudes

        d = compute_relative_altitudes(a)
        a.update(d)
        
        print "-- update", parent_path
        with open(parent_full_path, 'w') as f:    
            json.dump(a, f)
        
if __name__ == "__main__":

    # check token

    if len(ACCESS_TOKEN) == 0:
        print "-- get an access token for your app on https://www.strava.com/settings/api"
        sys.exit(1)

    # prepare directories
    
    for p in [ROOT_DIR, os.path.sep.join([ROOT_DIR, STRAVA_DIR]), os.path.sep.join([ROOT_DIR, PULSAR_DIR])]:
        if not os.path.exists(p):
            os.makedirs(p)
    
    # get athlete
        
    url = "https://www.strava.com/api/v3/athlete?access_token=" + ACCESS_TOKEN
    athlete = read_json_file_with_cache("athlete.json", url)
    
    # get activities list
    
    url = "https://www.strava.com/api/v3/activities?per_page=200&access_token=" + ACCESS_TOKEN
    activities = read_json_file_with_cache("activities.json", url, force_download=FORCE_REFRESH_ACTIVITIES)
    
    # get activities details
    
    for a in activities:
        
        url = "https://www.strava.com/api/v3/activities/" + str(a["id"]) + "/streams/altitude?resolution=medium&access_token=" + ACCESS_TOKEN
        stream = read_json_file_with_cache("strava/%d.json" % a["id"], url)

        # build pulsar_run activity

        pr_activity = build_pr_activity_if_needed(a)

    # merge activities to be merged

    merge_activities(activities_to_be_merged)
    
    # files are now ready to be drawn in PULSAR_DIR
