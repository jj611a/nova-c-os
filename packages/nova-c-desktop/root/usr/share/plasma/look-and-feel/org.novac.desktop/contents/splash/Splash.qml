/*
    Nova-C OS login splash (replaces Plasma's KDE splash): shown while the desktop starts after login.
    Same look as the boot splash: deep slate background, the Nova-C logo, a thin cyan progress bar.
    ksplashqml raises `stage` from 1 to 6 as the session starts, then closes the splash.
*/
import QtQuick

Rectangle {
    id: root
    property int stage

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#04070d" }
        GradientStop { position: 1.0; color: "#0c2233" }
    }

    onStageChanged: {
        if (stage == 2) {
            intro.running = true;
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        Image {
            id: logo
            readonly property real size: Math.min(root.width, root.height) * 0.22
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -size * 0.25
            source: "images/logo.png"
            sourceSize.width: size
            sourceSize.height: size
            fillMode: Image.PreserveAspectFit
            asynchronous: true

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.6; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.6; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
            }
        }

        Text {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: logo.size * 0.12
            text: "Nova-C OS"
            color: "#9ff4ff"
            font.pixelSize: Math.max(18, logo.size * 0.16)
            font.bold: true
        }

        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: title.bottom
            anchors.topMargin: logo.size * 0.18
            width: Math.max(160, logo.size * 1.2)
            height: 4
            radius: 2
            color: "#1b2f3f"

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "#4ce1f0"
                width: parent.width * Math.min(1, Math.max(0, root.stage) / 6)
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
            }
        }
    }

    OpacityAnimator {
        id: intro
        target: content
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.InOutQuad
    }
}
