import QtQuick
import qs.modules.bar.services // Time
import qs.modules.bar // BarComponent
import qs

BarComponent {
    content: Text {
        // required property string time
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        color: BarSetting.timeWidgetFont
        text: Time.time
    }
    backgroundColor: BarSetting.timeWidgetBackground
}
