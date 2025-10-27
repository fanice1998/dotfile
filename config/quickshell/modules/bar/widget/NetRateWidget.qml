import QtQuick
import qs.modules.bar
import qs

BarComponent {
    content: Text {
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: BarSetting.timeWidgetFont
        text: "DL/UL%"
    }
    backgroundColor: BarSetting.timeWidgetBackground
}
