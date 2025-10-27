import QtQuick
import qs.modules.bar
import qs

BarComponent {
    content: Text {
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: BarSetting.timeWidgetFont
        text: "Light"
    }
    backgroundColor: BarSetting.timeWidgetBackground
}
