# CalDigit TS4 + Apple USB SuperDrive: “Accessory Needs Power” fix

An Apple USB SuperDrive connected directly to a CalDigit TS4 USB-A port can show this macOS alert even when the [CalDigit SuperDrive driver](https://www.caldigit.com/superdrive-and-usb-charging-driver-installation-guide/) is installed and System Information says **Loaded: Yes**:

> Accessory Needs Power — MacBook Air SuperDrive. For additional power, connect to a USB port on this Mac.

In one verified case, explicitly loading the TS4 personalities of CalDigit’s installed driver and then reconnecting the dock’s **host Thunderbolt cable** resolved the power request. This is a troubleshooting case report, not a confirmed fix for every Mac, macOS release, or dock.

## Check these first

1. Confirm the SuperDrive is plugged **directly into a TS4 USB-A port**, without an intermediate hub or adapter.
2. If your Mac has a USB-A port, connect the drive directly to the Mac as a control test. In our case, the warning disappeared there. [Apple recommends a direct USB connection](https://support.apple.com/en-gb/102181) for this drive.
3. Follow [CalDigit’s SuperDrive driver installation guide](https://www.caldigit.com/superdrive-and-usb-charging-driver-installation-guide/) and use the driver from [CalDigit Downloads](https://downloads.caldigit.com/). In **System Information → Software → Extensions**, find `CalDigitUSBHubSupport` and check **Loaded: Yes**. Also check **Software → Disabled Software** for a blocked CalDigit extension. Follow CalDigit’s guide if installation or approval is incomplete.

The [TS4 firmware 45.1 notes](https://www.caldigit.com/ts4-macos-firmware-update-procedures/) describe improved compatibility on the **downstream Thunderbolt/USB4 ports**. That firmware is separate from the SuperDrive USB charging driver. Updating firmware alone did not resolve this case.

## What worked after the driver was already loaded

Run these commands in Terminal. `sudo` may ask for an administrator password. They invoke the **already installed** CalDigit driver; they do not download software or alter the dock firmware.

```sh
sudo kmutil load -b com.CalDigit.USBHubSupport -P TS4-2A
sudo kmutil load -b com.CalDigit.USBHubSupport -P TS4-2B
```

Both commands should exit successfully. Then:

1. Pause anything using devices attached to the TS4, and safely eject any storage **actually connected through the dock**.
2. Disconnect the TS4’s **host Thunderbolt cable from the Mac**, then reconnect it. The dock’s wall power need not be disconnected for this step.
3. Unplug and reconnect the SuperDrive to a TS4 USB-A port. Check whether the warning returns and whether macOS sees the drive.

These `kmutil` commands are specific to the TS4 driver personalities found in this case. Do not substitute personality names or apply them to a different dock without checking that dock’s driver.

## Measured result in one case

| Observation | Before | After |
| --- | ---: | ---: |
| TS4 USB hub power supply reported to macOS | No 6,000 mA CalDigit override | 6,000 mA |
| TS4 USB port current limit reported to macOS | 500 mA | 1,500 mA |
| SuperDrive requested power | 1,100 mA | 1,100 mA |
| SuperDrive allocated power | 500 mA | 1,100 mA |
| `kUSBFailedRequestedPower` | 1,100 mA | Absent |
| macOS power alert | Present | Gone |

System Information also listed the Apple SuperDrive under **Disc Burning** after the fix. We did **not** test reading or burning a disc, and we have **not** checked whether the fix survives a Mac restart.

The verified setup was an Apple silicon Mac Studio running macOS 27.0, a TS4 with firmware 45.1, and CalDigit’s USB Hub Support Driver installer version 4.2. We omit serial numbers, dock identifiers, account information, device logs, and screenshots to protect privacy.

## Why this may help

The official driver’s TS4 personalities specify a 6,000 mA hub supply and 1,500 mA per-port limits. Before the commands, those values were not present on the relevant live TS4 USB hub. After explicitly loading both personalities and reconnecting the host cable, macOS allocated the SuperDrive its requested 1,100 mA.

**Inference:** The driver appeared installed and loaded, but its TS4 power properties had not been applied to the live hub. We do not know why. This case does not establish whether the cause is macOS 27, driver matching, device enumeration order, or another factor. Ordinary restarts and dock power cycles had not corrected it in this case.

## If it still fails

- Recheck CalDigit’s **Loaded** and **Disabled Software** steps. A blocked or unloaded driver is a different problem.
- Try a different direct TS4 USB-A port, then repeat the direct-to-Mac control test.
- If the commands report an error, keep the exact error text for [CalDigit Support](https://www.caldigit.com/support/). Avoid changing macOS security settings beyond the official driver installation procedure.
- If direct-to-Mac works and the TS4 still fails, include the dock model, macOS version, driver version, firmware version, and **power values without serial numbers** in a support request. If no better solution is available, using the Mac’s USB-A port is the known working fallback in this case.
- If the warning returns after a restart, the two `kmutil` commands followed by a host-cable reconnect are a candidate manual recovery. Startup persistence remains untested; this guide does not recommend adding a login or boot automation yet.

## Related reports and sources

- [CalDigit: SuperDrive and USB Charging Driver Installation Guide](https://www.caldigit.com/superdrive-and-usb-charging-driver-installation-guide/) — official installation, approval, and loaded/disabled checks.
- [CalDigit: TS4 macOS Firmware Update Procedures](https://www.caldigit.com/ts4-macos-firmware-update-procedures/) — firmware 45.1 purpose.
- [Apple: Connect and use your SuperDrive](https://support.apple.com/en-gb/102181) — direct connection guidance.
- [CalDigit community: Apple SuperDrive power boost across TB4 docks](https://www.reddit.com/r/CalDigit/comments/1gw3qt9/apple_superdrive_power_boost_across_t4_dock/) and [TS3+ charging driver discussion](https://www.reddit.com/r/CalDigit/comments/1ir4o4y/ts3_usb_charging_drivers_not_working_with_macos/) — other user reports; useful context, not proof of the cause or this fix.

If this works or fails on another setup, please open an issue with the dock model, macOS version, driver version, firmware version, exact command errors, and observed result. **Redact serial numbers, hardware UIDs, usernames, email addresses, and full system reports** before posting.

This is an independent community case report and is not affiliated with CalDigit or Apple.
