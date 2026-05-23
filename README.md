# KeepAwake

KeepAwake is a small macOS menu bar app that starts and stops `/usr/bin/caffeinate` with the flags you select.

## Features

- Runs as a menu bar app (no Dock icon)
- Simple UI with common `caffeinate` flags
- Start/Stop button to launch or terminate the background `caffeinate` process
- Open at Login toggle using macOS Login Items

## Included flags

- `-d` Prevent display sleep
- `-i` Prevent idle sleep
- `-m` Prevent disk sleep
- `-s` Prevent system sleep
- `-u` Declare user activity

## Open in Xcode

```bash
cd ~/Developer/KeepAwake
xcodegen generate
open KeepAwake.xcodeproj
```

## Optional CLI build

```bash
cd ~/Developer/KeepAwake
./scripts/build_app.sh
open dist/KeepAwake.app
```

## Notes

- While KeepAwake is running, the selected flags are locked until you stop the process.
- If no flags are selected, `caffeinate` still runs with its default behavior.
- The Xcode project is generated from `project.yml`.
