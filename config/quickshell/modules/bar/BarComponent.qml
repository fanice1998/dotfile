import QtQuick
import QtQuick.Layouts
// import QtQuick.Window
import Quickshell.Widgets
import qs

// Rectangle {
Item {
    id: barComponent
    property real margin: 5
    default property alias content: child.child
    property string backgroundColor

    implicitWidth: child.implicitWidth + 15
    implicitHeight: BarSetting.barHeight

    WrapperRectangle {
        id: child

        anchors.fill: parent
        radius: 30
        border.color: "white"
        border.width: 1
        antialiasing: true
        resizeChild: true
        color: barComponent.backgroundColor
    }
    // default property alias content: barComponent.children
}


