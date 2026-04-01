#!/usr/bin/env bash
BROWSER="zen-browser"
WEATHER_LOCATION_URL="${WEATHER_LOCATION_URL:-https://www.meteoschweiz.admin.ch/lokalprognose/zuerich/8001.html#forecast-tab=weekly-overview}"

$BROWSER "$WEATHER_LOCATION_URL"