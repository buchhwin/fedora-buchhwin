import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    Theme { id: theme }
    property var state: ({"lockMinutes":10,"displayMinutes":15,"suspendMinutes":30,"nightLight":false,"temperature":4000})
    color: theme.surface2; border.width: 1; border.color: theme.border
    implicitHeight: content.implicitHeight + 28
    function refresh() { if (!reader.running) reader.running=true }
    function setValue(key,value) { writer.command=["buchhwin-sessionctl","set",key,String(value)]; writer.running=true }
    Component.onCompleted: refresh()
    Process { id: reader; command:["buchhwin-sessionctl","state"]; stdout: StdioCollector { onStreamFinished: { try { root.state=JSON.parse(text) } catch(e) {} } } }
    Process { id: writer; onExited: root.refresh() }
    ColumnLayout { id: content; anchors.fill: parent; anchors.margins: 14; spacing: 10
        Text { text:"Power and comfort"; color:theme.text; font.family:theme.font; font.pixelSize:15; font.bold:true }
        Text { text:"These timers run only inside the dwl session."; color:theme.subtext; font.family:theme.font; font.pixelSize:10 }
        Repeater { model:[["Automatic lock","lockMinutes",[0,5,10,15,30]],["Turn displays off","displayMinutes",[0,5,10,15,30]],["Suspend","suspendMinutes",[0,15,30,60,120]]]
            delegate: RowLayout { id: settingRow; required property var modelData; readonly property string settingKey:modelData[1]; Layout.fillWidth:true
                Text { Layout.preferredWidth:180; text:modelData[0]; color:theme.text; font.family:theme.font; font.pixelSize:11 }
                Repeater { model:modelData[2]; delegate: Rectangle { required property int modelData; width:58; height:30; radius:6; color:root.state[settingRow.settingKey]===modelData?theme.blue:theme.bg
                    Text { anchors.centerIn:parent; text:modelData===0?"Off":modelData+" min"; color:root.state[settingRow.settingKey]===modelData?theme.bg:theme.text; font.family:theme.font; font.pixelSize:9 }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:root.setValue(settingRow.settingKey,modelData) }
                } }
            }
        }
        RowLayout { Layout.fillWidth:true
            Text { Layout.preferredWidth:180; text:"Night light"; color:theme.text; font.family:theme.font; font.pixelSize:11 }
            Rectangle { width:76; height:30; radius:6; color:root.state.nightLight?theme.blue:theme.bg
                Text { anchors.centerIn:parent; text:root.state.nightLight?"On":"Off"; color:root.state.nightLight?theme.bg:theme.text; font.family:theme.font }
                MouseArea { anchors.fill:parent; onClicked:root.setValue("nightLight",!root.state.nightLight) }
            }
            Text { text:"Warmth"; color:theme.subtext; font.family:theme.font; font.pixelSize:10 }
            ValueSlider { Layout.fillWidth:true; from:2500; to:5500; value:root.state.temperature; onValueEdited:value=>root.setValue("temperature",Math.round(value/100)*100) }
        }
    }
}
