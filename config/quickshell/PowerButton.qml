import QtQuick
import qs.Commons
import qs.Ui

// The bar's first button, where Omarchy has its logo menu: the power menu.
BarWidget {
  id: root
  moduleName: "omarchy.power-menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: I18n.t("bar.powerMenu")
    onPressed: function() { root.bar.run("~/.local/bin/logoutmenu") }
  }
}
