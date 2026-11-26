import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar as Bar
import qs.bar.widgets as Widgets
import qs.panels.agents as Agents
import qs.panels.audio as Audio
import qs.panels.bluetooth as Bluetooth
import qs.panels.clock as Clock
import qs.panels.network as Network
import qs.panels.tailscale as Tailscale
import qs.services.media as Media
import qs.services.nightlight as Nightlight
import "BarHost.js" as Host

// Mounts the bar (bar/, panels/, services/, from Omarchy) and stands in for Omarchy's shell
// host: the widgets a layout can name, the layout file and the services widgets ask for.
Item {
  id: host

  // Outside the shell's directory: the bar writes it, and a write there would reload the shell.
  property string configPath: Quickshell.env("HOME") + "/.config/bar/bar.json"
  // The notification daemon, for the Do Not Disturb indicator.
  property var notifications: null

  // The layout file as the bar reads it: position, background, layout.
  property var barConfig: ({})
  readonly property var shellConfig: ({ bar: barConfig })

  function save(bar) {
    barConfig = bar
    file.setText(Host.serialize(bar))
  }

  // What the bar and its widgets call on their host.
  function mutateShellConfig(mutator) {
    var copy = JSON.parse(JSON.stringify(shellConfig))
    mutator(copy)
    save(copy.bar)
  }

  function updateEntryInline(id, settings) {
    var next = Host.withEntry(barConfig, id, settings)
    if (!next) {
      return false
    }

    save(next)
    return true
  }

  // Panels open from their widget on the bar. Upstream's other surfaces (its OSD, the
  // Wi-Fi QR card, the speed test) are not carried here, and asking for one does nothing.
  function summon(id, payloadJson) { return bar.summonBarWidget(id) }
  function toggle(id, payloadJson) { return bar.isBarWidgetOpen(id) ? bar.hideBarWidget(id) : bar.summonBarWidget(id) }

  readonly property var services: ({
    "omarchy.notifications": notifications, "omarchy.media": media,
    "omarchy.nightlight": nightlight, "omarchy.idle": stayAwake
  })
  function firstPartyServiceFor(id) { return services[id] || null }

  Media.Service { id: media; shell: host }
  Nightlight.Service { id: nightlight; shell: host }
  StayAwake { id: stayAwake }

  FileView {
    id: file
    path: host.configPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var bar = Host.parse(text())
      if (!bar) {
        console.warn("bar: " + host.configPath + " is not a layout; keeping the last one")
        return
      }

      host.barConfig = bar
    }
  }

  // What a layout can name.
  readonly property var widgets: ({
    "power-menu": powerMenu, "workspaces": workspaces, "active-window": activeWindow, "tray": tray,
    "keyboard-layout": keyboardLayout, "indicators": indicators, "microphone": microphone, "spacer": spacer,
    "clock": clock, "media": mediaWidget, "audio": audio, "bluetooth": bluetooth, "network": network,
    "tailscale": tailscale, "agents": agents
  })
  Component { id: powerMenu; PowerButton {} }
  Component { id: workspaces; Widgets.Workspaces {} }
  Component { id: activeWindow; Widgets.ActiveWindow {} }
  Component { id: tray; Widgets.Tray {} }
  Component { id: keyboardLayout; Widgets.KeyboardLayout {} }
  Component { id: indicators; Widgets.Indicators {} }
  Component { id: microphone; Widgets.Microphone {} }
  Component { id: spacer; Widgets.Spacer {} }
  Component { id: clock; Clock.BarWidget {} }
  Component { id: mediaWidget; Media.BarWidget {} }
  Component { id: audio; Audio.Panel {} }
  Component { id: bluetooth; Bluetooth.Panel {} }
  Component { id: network; Network.Panel {} }
  Component { id: tailscale; Tailscale.Panel {} }
  Component { id: agents; Agents.Panel {} }

  Bar.BarWidgetRegistry { id: registry }

  Component.onCompleted: {
    for (var name in widgets) {
      // firstParty hands the widget the bar itself, as upstream's own widgets get it
      registry.register(Host.fullId(name), widgets[name], { firstParty: true })
    }
  }

  Bar.Bar {
    id: bar
    barWidgetRegistry: registry
    barConfig: host.barConfig
    shell: host
  }
}
