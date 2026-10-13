# Local companion relay (development)

The iPhone is the authority for companion actions and imported Apple Health / calendar allocations. Watch uses WatchConnectivity directly. Mac and CoreS3 SE use this explicit local relay. State is held in RAM; restarting the relay clears it. No cloud account or background service is installed.

## Start on your Mac

From the parent `timebite-official` directory:

```sh
export TIMEBITE_PHONE_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
export TIMEBITE_COMPANION_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
python3 Tools/CompanionRelay/relay.py --host 0.0.0.0
```

Keep that terminal open. Copy the phone token into iPhone **Profile → Watch / Mac / M5Stack** and enable Connect companion relay. Use `http://YOUR-MAC.local:8765` as the URL (find your LocalHostName in macOS Sharing settings). iOS Simulator and Mac can use `http://localhost:8765`. A physical iPhone cannot use localhost to reach your Mac. Allow local-network access when prompted. Do not expose port 8765 to the Internet; this test transport uses HTTP, so use a trusted local test network. HTTPS can terminate at your own trusted reverse proxy for Apple clients; M5 firmware currently uses the local HTTP test endpoint.

To see/copy the two token values in your own terminal, use `printf '%s\n' "$TIMEBITE_PHONE_TOKEN"` and `printf '%s\n' "$TIMEBITE_COMPANION_TOKEN"`. Do not commit them. Apple UI keeps the token only for the current launch. Firmware's `include/secrets.h` is ignored by its repo.

On Mac choose **iPhone Companion**, enter the same URL and **companion** token, and enable connection. For firmware use the companion token in `include/secrets.h`. Keep iPhone TimeBite foregrounded: state publishes every five seconds, and it polls for controls. The relay stops receiving new state while iOS suspends the app; clients mark it stale after two minutes. Pending controls expire after 30 seconds. `202` means waiting for iPhone, not execution. Only iPhone can acknowledge execution. Watch commands require immediate reachability and never queue offline controls.

This is one-phone development pairing. Different phone and companion tokens enforce publisher/consumer roles. There is no discovery, Internet hosting, durable offline queue, multiple-phone conflict authority, or production pairing UI.

## Verify transport

```sh
python3 -m unittest discover -s Tools/CompanionRelay
```

The tests use synthetic protocol objects on loopback; they do not inject Health data into the apps. See `docs/companion-testing.md` for real-data checks.
