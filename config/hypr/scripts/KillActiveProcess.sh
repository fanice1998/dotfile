# #!/bin/bash
# 
# Get id of an active windows
active_pid=$(hyprctl activewindow | grep -o "\"pid\"": [0-9]*' | cut -d' ' -f2')

# Close active window
kill $active_pid
