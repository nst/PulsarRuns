# PulsarRuns
Pulsar-plot of Strava runs

Inspired by [http://www.xavigimenez.net/blog/2015/05/plotting-my-strava-running-activity-as-a-pulsar-plot/](http://www.xavigimenez.net/blog/2015/05/plotting-my-strava-running-activity-as-a-pulsar-plot/)

__Python Version__

Requires the requests and cairo modules.

1. get a Strava access token from [https://www.strava.com/settings/api](https://www.strava.com/settings/api) and put on top of `pulsar_runs_data.py`.
2. run `pulsar_runs_data.py` to download your activites
3. run `pulsar_runs_draw.py` to draw your activities

__Swift Version (Unmaintained)__

1. get a Strava access token from [https://www.strava.com/settings/api](https://www.strava.com/settings/api) and put it in `downloadAndDumpAthleteAndActivities()`
2. run the code once to download the data and save it in `/tmp`
3. set `download` to `false` and run the code again to draw the picture

![PulsarRuns](https://raw.githubusercontent.com/nst/PulsarRuns/master/nicolas_seriot.png)
