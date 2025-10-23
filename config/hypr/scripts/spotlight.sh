#!/bin/bash
# Like Mac Spotlight
case $(echo -e "Apps\nScreenshot\nCalculator" | wofi --show dmenu --prompt "Spotlight" --insensitive) in "Apps")
    wofi --show drun ;;
  "Screenshot")
    grim -g "$(slurp)" - | wl-copy ;;
  "Caluculator")
    echo "scale=4; $1" | bc -l | wofi --dmenu ;;
esac
EOF


