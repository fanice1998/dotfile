pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland

import QtQuick
import QtQuick.Layouts
import qs.modules.bar.widget
import qs
// import qs.modules.bar.services

Scope {
    // id: root
    // property string time
    // Time { id: timeSource}

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            color: "#50000000"

            anchors {top: true;left: true; right: true}
            implicitHeight: BarSetting.barHeight

            RowLayout {
                anchors.fill: parent

                // Left Bar
                RowLayout {
                    // anchors.fill: parent
                    Layout.fillWidth: true
                    layoutDirection: Qt.LeftToRight
                    spacing: 7

                    TimeWidget {}
                    WeatherWidget {}
                    AppWidget {}
                    WorkspaceWidget {}
                }

                // Center Bar: Window Infomation
                BarComponent {
                    Layout.alignment: Qt.AlignCenter
                    Layout.minimumWidth: 0
                    content: Item {
                        // Layout.fillWidth: true
                        // Layout.minimumWidth: 0
                        implicitWidth: windowInfo.implicitWidth


                        Text {
                            id: windowInfo

                            property var focusedWindow: Hyprland.activeToplevel

                            anchors.centerIn: parent

                            color: "white"
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter

                            text: focusedWindow? focusedWindow.title: "No active window"
                        }
                    }
                    backgroundColor: "#50FFFFFF"
                }

                // Right Bar
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.fillWidth: true
                    layoutDirection: Qt.RightToLeft
                    spacing: 7

                    BatteryWidget {}
                    WifiWidget {}
                    VolumeWidget {}
                    LightWidget {}
                    BluetoothWidget {}
                    NetRateWidget {}
                }
            }
        }
    }
}
