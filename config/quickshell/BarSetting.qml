pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: setting
    property int barHeight: 30

    // Color
    property string timeWidgetBackground: "#333333"
    property string timeWidgetFont: "white"
}
