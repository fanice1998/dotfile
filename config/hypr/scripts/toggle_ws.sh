#!/bin/bash
TARGET_WS=$1
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
echo "taget: $TARGET_WS, current: $CURRENT_WS" >> /tmp/tmp.txt
if [ "$CURRENT_WS" == "$TARGET_WS" ]; then
    hyprctl dispatch workspace previous  # 回上一個
else
    hyprctl dispatch workspace $TARGET_WS  # 切到目標
fi
