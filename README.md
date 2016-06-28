# PulsarRuns
Pulsar-plot of Strava runs in Swift 3

Inspired by [http://www.xavigimenez.net/blog/2015/05/plotting-my-strava-running-activity-as-a-pulsar-plot/](http://www.xavigimenez.net/blog/2015/05/plotting-my-strava-running-activity-as-a-pulsar-plot/)

__Usage__

1. get a Strava access token from [https://www.strava.com/settings/api](https://www.strava.com/settings/api) and put it in `downloadAndDumpAthleteAndActivities()`
2. run the code once to download the data and save it in `/tmp`
3. set `download` to `false` and run the code again to draw the picture

You may have to modify some constants to get a nice looking result.

![PulsarRuns](https://raw.githubusercontent.com/nst/PulsarRuns/master/nicolas_seriot.png)
