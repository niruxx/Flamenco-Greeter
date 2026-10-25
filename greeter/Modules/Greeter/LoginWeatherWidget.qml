import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

// Current weather and the next three days, from Flamenco Shell's Weather
// service (Open-Meteo). The city is set on the widget itself while editing,
// so it belongs to the login screen rather than to anyone's synced settings.
LoginWidgetCard {
    id: root

    required property var widget
    property bool editing: false

    readonly property string city: widget?.config?.city ?? ""
    readonly property bool fahrenheit: widget?.config?.fahrenheit ?? false

    function apply() {
        const w = Settings.data.weather;
        if (w.city !== city)
            w.city = city;
        if (w.fahrenheit !== fahrenheit)
            w.fahrenheit = fahrenheit;
        if (!w.enabled)
            w.enabled = true;
    }
    onCityChanged: {
        apply();
        if (!cityInput.activeFocus && cityInput.text !== city)
            cityInput.text = city;
    }
    onFahrenheitChanged: apply()
    Component.onCompleted: apply()
    // Settings may still be reading its file, which would undo the city: set it again once loaded
    Connections {
        target: Settings
        function onReadyChanged() { root.apply(); }
    }

    ColumnLayout {
        width: 250
        spacing: Theme.sp2

        // set up while editing
        RowLayout {
            visible: root.editing
            Layout.fillWidth: true
            spacing: Theme.sp2

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 18
                color: Theme.alpha(Theme.surfaceHigh, 0.9)
                border.width: 1
                border.color: cityInput.activeFocus ? Theme.accent : Theme.alpha(Theme.border, 0.6)

                TextInput {
                    id: cityInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMd
                    Component.onCompleted: text = root.city
                    onEditingFinished: GreeterWidgets.configure(root.widget.id, "city", text.trim())
                }
                FText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    visible: cityInput.text === ""
                    text: "City"
                    dim: true
                }
            }
            FIconButton {
                icon: "device_thermostat"
                size: 36
                flat: false
                onClicked: GreeterWidgets.configure(root.widget.id, "fahrenheit", !root.fahrenheit)
            }
            FText {
                text: root.fahrenheit ? "°F" : "°C"
                dim: true
            }
        }

        RowLayout {
            visible: Weather.ready && root.city !== ""
            spacing: Theme.sp3
            FIcon {
                icon: Weather.icon
                size: 48
                fill: 1
                color: Theme.accent
            }
            ColumnLayout {
                spacing: 0
                FText {
                    text: Math.round(Weather.temp) + Weather.unit
                    font.pixelSize: Theme.fsXxl
                    font.weight: Font.Bold
                }
                FText {
                    text: Weather.description + (Weather.place ? " · " + Weather.place : "")
                    dim: true
                    Layout.maximumWidth: 170
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            visible: Weather.ready && root.city !== "" && Weather.daily.length > 1
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: Weather.daily.slice(1, 4)
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    FText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(new Date(modelData.date), "ddd")
                        dim: true
                        font.pixelSize: Theme.fsSm
                    }
                    FIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: Weather.iconFor(modelData.code, true)
                    }
                    FText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(modelData.max) + "° " + Math.round(modelData.min) + "°"
                        font.pixelSize: Theme.fsSm
                    }
                }
            }
        }

        RowLayout {
            visible: !Weather.ready || root.city === ""
            spacing: Theme.sp2
            FIcon {
                icon: root.city === "" ? "location_off" : "cloud_off"
                color: Theme.textDim
            }
            FText {
                text: root.city === "" ? (root.editing ? "Type a city above" : "No city set") : "Weather unavailable"
                dim: true
            }
        }
    }
}
