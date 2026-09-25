# Experimental software reset for the TS4 USB 2 hub

This is a manual, on-demand workaround. A long-press Stream Deck button calls a Keyboard Maestro macro, which asks for a macOS administrator password, loads CalDigit's already-installed TS4 driver personalities, and resets the **inner TS4 USB 2 hub containing the Apple USB SuperDrive**. The reset briefly disconnects every USB device on that hub. It does not reset the entire TS4 Thunderbolt connection.

**Test status:** On macOS 27.0 with TS4 firmware 45.1, the button caused the selected hub and SuperDrive to receive new I/O Registry identities. The SuperDrive then showed a 1,100 mA allocation with no `kUSBFailedRequestedPower` flag. A camera and UPS on the same hub reappeared. This test started while the drive was already receiving full power; **we have not yet established whether this software reset restores power after the reboot failure** described in the [main case report](README.md#reboot-follow-up). We have not tested disc reading or burning.

## How it works

- [`ts4_hub_reset.m`](experimental/ts4_hub_reset.m) finds exactly one Apple USB SuperDrive (`05ac:1500`), follows its I/O Registry parents, and accepts only a CalDigit TS4 inner USB 2 hub (`2188:5511` or `2188:5512`). It refuses to reset anything else. `--probe` is read-only; `--reset` requires root. It uses Apple's `IOUSBHostDevice` device-capture and destroy operations to re-enumerate the selected hub.
- [`ts4-superdrive-recover.sh`](experimental/ts4-superdrive-recover.sh) loads the two installed CalDigit TS4 driver personalities, invokes that reset, and waits for the SuperDrive to receive a new I/O Registry identity and a 1,100 mA allocation without a failed-power flag. The script exits nonzero if it cannot verify both conditions.
- Keyboard Maestro runs the script with `osascript`'s `with administrator privileges`, so macOS prompts for an administrator password on each press. There is no login item, background reset, or passwordless `sudo` rule.

## Build and install on a matching Mac

Review the source and confirm that your drive is connected through the same TS4 USB 2 hub before running it. The helper requires the macOS SDK and Xcode command-line tools.

```sh
clang -fobjc-arc -framework Foundation -framework IOKit -framework IOUSBHost \
  experimental/ts4_hub_reset.m -o ts4-hub-reset
codesign --force --sign - ts4-hub-reset
./ts4-hub-reset --probe
sudo install -o root -g wheel -m 755 ts4-hub-reset /usr/local/libexec/ts4-hub-reset
sudo install -o root -g wheel -m 755 experimental/ts4-superdrive-recover.sh \
  /usr/local/libexec/ts4-superdrive-recover
```

The `--probe` result should identify a CalDigit TS4 USB 2 hub. Keep the SuperDrive plugged into the TS4 for the reset. Pause work using devices on the same hub; eject any storage attached there before pressing the button.

In Keyboard Maestro, create an enabled macro with an **Execute Shell Script** action containing:

```sh
if /usr/bin/osascript -e 'do shell script "/usr/local/libexec/ts4-superdrive-recover" with administrator privileges'; then
  /usr/bin/osascript -e 'display notification "SuperDrive has 1,100 mA. The TS4 USB hub reset worked." with title "TS4 reset complete"'
else
  /usr/bin/osascript -e 'display notification "The reset did not verify SuperDrive power. Check the USB connection." with title "TS4 reset needs attention"'
  exit 1
fi
```

Assign that macro to a Stream Deck **Key Logic** hold action using KM Link. Leave the single- and double-press actions empty to make accidental activation less likely. The selected USB hub and its children will briefly disconnect when the hold action runs. The success notification means re-enumeration and the *power allocation check* passed; it does not prove a disc can be read or burned.

If you test this after a reboot where the power warning has returned, please report whether the warning disappears and include only the power values and error text. Remove serial numbers, usernames, device UIDs, and full system reports before posting.
