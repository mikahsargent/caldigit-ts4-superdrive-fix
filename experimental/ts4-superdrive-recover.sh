#!/bin/zsh
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  print -u2 'Recovery requires administrator privileges.'
  exit 4
fi

reset_tool=/usr/local/libexec/ts4-hub-reset

# Register both official CalDigit TS4 property-merge personalities first.
/usr/bin/kmutil load -b com.CalDigit.USBHubSupport -P TS4-2A
/usr/bin/kmutil load -b com.CalDigit.USBHubSupport -P TS4-2B

# The helper refuses to act unless one Apple SuperDrive is below a matching
# CalDigit TS4 USB 2 hub. It resets that hub and its attached USB devices.
"${reset_tool}" --probe
before=$(/usr/sbin/ioreg -r -n 'MacBook Air SuperDrive' -l -w0 |
  /usr/bin/sed -n '1s/.* id \(0x[[:xdigit:]]*\),.*/\1/p')
if [[ -z "${before}" ]]; then
  print -u2 'Could not identify the SuperDrive before reset.'
  exit 5
fi
"${reset_tool}" --reset

for attempt in {1..15}; do
  /bin/sleep 1
  state=$(/usr/sbin/ioreg -r -n 'MacBook Air SuperDrive' -l -w0 2>/dev/null || true)
  after=$(print -r -- "${state}" | /usr/bin/sed -n '1s/.* id \(0x[[:xdigit:]]*\),.*/\1/p')
  if [[ -n "${after}" && "${after}" != "${before}" &&
        "${state}" == *'"UsbPowerSinkAllocation" = 1100'* &&
        "${state}" != *'"kUSBFailedRequestedPower"'* ]]; then
    print 'SuperDrive re-enumerated with 1,100 mA allocated and no failed-power flag.'
    exit 0
  fi
done

print -u2 'Hub reset completed, but SuperDrive re-enumeration and power were not verified.'
exit 1
