import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

// This month at a glance, today marked in the accent color.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false

    readonly property date today: Time.now
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday
    // the Sunday/Monday on or before the 1st, then 42 days from there
    readonly property date gridStart: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        return new Date(first.getFullYear(), first.getMonth(), 1 - ((first.getDay() - firstDay + 7) % 7));
    }

    ColumnLayout {
        spacing: Theme.sp2
        width: 7 * 34

        FText {
            text: Qt.formatDate(root.today, "MMMM yyyy")
            font.pixelSize: Theme.fsLg
            font.weight: Font.Bold
        }

        Grid {
            columns: 7
            spacing: 0

            Repeater {
                model: 7
                FText {
                    required property int index
                    width: 34
                    height: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                    dim: true
                    font.pixelSize: Theme.fsSm
                }
            }

            Repeater {
                model: 42
                Item {
                    required property int index
                    readonly property date day: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                    readonly property bool isToday: day.toDateString() === root.today.toDateString()
                    readonly property bool inMonth: day.getMonth() === root.today.getMonth()
                    width: 34
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28; radius: 14
                        color: Theme.accent
                        visible: parent.isToday
                    }
                    FText {
                        anchors.centerIn: parent
                        text: parent.day.getDate()
                        color: parent.isToday ? Theme.onAccent : parent.inMonth ? Theme.text : Theme.textDim
                        opacity: parent.inMonth ? 1 : 0.5
                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
