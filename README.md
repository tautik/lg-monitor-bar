# LG Monitor Bar

A macOS menu bar app that changes an external monitor's settings over DDC/CI, so you never reach for the buttons on the back.

Brightness, contrast, sharpness, volume, colour preset, red/green/blue gain and input, from a sun icon next to the battery.

Built for an LG UltraWide on an M4 Pro MacBook Pro (macOS 26). It should work with most DDC-capable monitors plugged straight into an Apple Silicon Mac; the input buttons use LG's codes.

## Install

Needs Apple Silicon, macOS 14 or later, and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/tautik/lg-monitor-bar.git
cd lg-monitor-bar
./scripts/build-app.sh --install
```

This builds `LG Monitor Bar.app`, copies it to `~/Applications` and starts it. Tick **Open at login** in the panel to keep it running.

**Keep Mac awake with lid closed** stops a closed-lid Mac from sleeping when the monitor switches to another input. It flips `pmset disablesleep`, so macOS asks for your password each time. Untick it when you're done: while it is on the Mac never sleeps, even on battery.

## Command line

The same controls without the UI, handy for Shortcuts, Raycast or a hotkey tool:

```bash
swift build -c release --product lgbar
.build/release/lgbar brightness 40
.build/release/lgbar input 210        # LG: 210 USB-C, 208 DisplayPort, 144 HDMI 1, 145 HDMI 2
```

Settings: `brightness contrast colorPreset redGain greenGain blueGain volume sharpness mute power input`, or any raw VCP code in hex.

## Tested

LG UltraWide (3440x1440) on an M4 Pro MacBook Pro, macOS 26.

| Connection | Result |
|---|---|
| Mac's built-in HDMI port, direct cable | Brightness works, no link drops while dragging the slider. Other settings not yet checked by eye. |
| USB-C adapter with HDMI out (Algoltek `AG6320` bridge chip) | Unreliable. In some stretches every write makes the adapter drop the video link and the screen goes black for a few seconds. |

## If the screen goes black when you change a setting

Check what sits between the Mac and the monitor. A USB-C hub, dongle or USB-C-to-HDMI cable has its own bridge chip that has to pass DDC along, and some reset the video link when they get a DDC write. macOS logs `display HPD removed` right after the write when this happens:

```bash
log show --last 5m --predicate 'process == "kernel" AND eventMessage CONTAINS "display HPD"'
```

Plug the monitor straight into the Mac (built-in HDMI, or a USB-C to DisplayPort cable). Sending each message once instead of twice does not help. Other monitors show the same symptom with MonitorControl ([discussion 1371](https://github.com/MonitorControl/MonitorControl/discussions/1371)), and Lunar's author describes it as hardware that software can't fix ([notes](https://notes.alinpanaitiu.com/Weird%20monitor%20bugs)).

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
