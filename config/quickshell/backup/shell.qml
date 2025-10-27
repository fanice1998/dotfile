import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray as System
import qs.modules.bar

ShellRoot {
    id: root

    Loader {
        id: barLoader
        active: true
        sourceComponent: barComponent
    }
  Component {
      id: barComponent  // Changed from BarComponent

      PanelWindow {
          anchors { top: true; left: true; right: true }
          height: 30
          color: "#00000000"
          // margins {top: 5; left: 5; right:5}
      BarComponent{
          id: topBar

          RowLayout {
              anchors.fill: parent
              spacing: 10

              // 左：時間
            BarComponent{
                Layout.fillHeight: true
                ColumnLayout {
                    Layout.alignment: Qt.AlignLeft
                    Layout.preferredWidth: 100

                Text {
                    Layout.fillHeight: true
                    id: timeText
                    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                    color: "gray"
                    font.pixelSize: 14

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                    }
                }
            }

              // 中：當前焦點視窗資訊
              // Item {
              //     Layout.fillWidth: true
              //     Layout.minimumWidth: 0

              //     Text {
              //         id: windowInfo
              //         anchors.centerIn: parent
              //         text: focusedWindow ? focusedWindow.title : "No active window"
              //         color: "white"
              //         font.pixelSize: 12
              //         elide: Text.ElideRight
              //         horizontalAlignment: Text.AlignHCenter

              //         // property var focusedWindow: Hyprland.focusedWindow
              //         property var focusedWindow: Hyprland.activeToplevel
              //     }
              // }
          }
        }
      }
    }
  }
}

