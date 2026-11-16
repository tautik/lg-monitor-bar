# LG Monitor Bar

A macOS menu bar app that changes an external monitor's settings over DDC/CI, so you never reach for the buttons on the back.

Brightness, contrast, sharpness, volume, colour preset, red/green/blue gain and input, from a sun icon next to the battery.

Built for an LG UltraWide on an M4 Pro MacBook Pro (macOS 26) over USB-C. It should work with most DDC-capable monitors on Apple Silicon over USB-C or DisplayPort; the input buttons use LG's codes.

## Install

Needs Apple Silicon, macOS 14 or later, and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/tautik/lg-monitor-bar.git
cd lg-monitor-bar
./scripts/build-app.sh --install
```

This builds `LG Monitor Bar.app`, copies it to `~/Applications` and starts it. Tick **Open at login** in the panel to keep it running.

## Command line

The same controls without the UI, handy for Shortcuts, Raycast or a hotkey tool:

```bash
swift build -c release --product lgbar
.build/release/lgbar brightness 40
.build/release/lgbar input 210        # LG: 210 USB-C, 208 DisplayPort, 144 HDMI 1, 145 HDMI 2
```

Settings: `brightness contrast colorPreset redGain greenGain blueGain volume sharpness mute power input`, or any raw VCP code in hex.

## Tested on an LG UltraWide over USB-C

**Not reliable on this monitor.** In some stretches every write, whatever the setting or value, makes the monitor drop the DisplayPort link: the screen goes black for a few seconds and macOS logs `display HPD removed` right after the write. In other stretches about 20 writes in a row went through with no drop. The bad stretches started after a display sleep/wake. No setting has been confirmed by eye yet.

What is known:

- The bytes are the standard Set VCP message, the same ones m1ddc and MonitorControl send. Sending once instead of twice does not prevent the drop.
- Other monitors on USB-C show the same thing with MonitorControl ([discussion 1371](https://github.com/MonitorControl/MonitorControl/discussions/1371)), and Lunar's author describes monitors that lose signal on any DDC traffic as a firmware problem with no software fix ([notes](https://notes.alinpanaitiu.com/Weird%20monitor%20bugs), [FAQ](https://lunar.fyi/faq)).
- This monitor's USB-C port reports DisplayPort sink ID `AG6320`, which looks like a DisplayPort-to-HDMI bridge chip inside the monitor. Unconfirmed as the cause.
- LG's OnScreen Control uses a USB HID device (043E:9A39) on some models instead of the video link. This monitor does not expose one over USB-C.

Worth trying: an HDMI or DisplayPort cable instead of USB-C.

## Limits

- **Write-only.** On an M4 Pro with macOS 26 the monitor's replies to DDC reads come back as noise (168 combinations of framing, offset, length and timing tried), the same problem [MonitorControl#1831](https://github.com/MonitorControl/MonitorControl/issues/1831) reports. So the panel shows the last values set from the app, not what the monitor reports. Changes made with the monitor's own buttons won't show up.
- **No LG-only features.** Picture modes (Gamer, Reader), response time and black stabilizer aren't exposed over DDC. Use LG's OnScreen Control for those.
- **First external display only.**
- **Private API.** It talks to the display through the undocumented `IOAVService` calls, like m1ddc and MonitorControl do, so a macOS update could break it.

## Development

```bash
swift test                     # packet bytes and write coalescing
swift build                    # debug build of the app and lgbar
log stream --predicate 'subsystem == "lg-monitor-bar"'   # every write the app sends
```

The DDC message framing and LG input codes come from [m1ddc](https://github.com/waydabber/m1ddc) and [MonitorControl](https://github.com/MonitorControl/MonitorControl), both MIT.

## License

MIT
