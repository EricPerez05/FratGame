# Next Steps: Roblox Studio + VS Code

Use this after your Rojo connection is working.

## Goal

Move from test scripts to your real game code safely, without breaking the place.

## 1) Keep Rojo running

In VS Code terminal, run:

```powershell
cd "e:\BuildAClub"
rojo serve
```

Leave this terminal open while developing.

## 2) Connect in Studio

1. Open your place in Roblox Studio.
2. Open the Rojo plugin.
3. Connect to `localhost:34872`.
4. Confirm your Explorer contains synced folders:
   - `ServerScriptService > Server`
   - `StarterPlayer > StarterPlayerScripts > Client`
   - `ReplicatedStorage > Shared`

## 3) Replace test code with a simple bootstrap

### Server bootstrap (`src/server/init.server.luau`)

```luau
print("[Server] boot ok")
```

### Client bootstrap (`src/client/init.client.luau`)

```luau
print("[Client] boot ok")
```

Press Play and confirm both logs appear (Server and Client output views).

## 4) Create migration folders

Inside `src`, use this structure:

- `src/server/Systems`
- `src/server/Services`
- `src/client/Controllers`
- `src/client/UI`
- `src/shared/Modules`
- `src/shared/Config`
- `src/shared/Remotes`

## 5) Migrate scripts in small batches

Do not move everything at once.

1. Pick one feature (example: inventory).
2. Move only that feature's scripts into the folders above.
3. Fix requires and paths.
4. Test in Play mode.
5. Commit.
6. Repeat with next feature.

## 6) Handle remotes clearly

Put networking definitions under `src/shared/Remotes`.

- Name remotes by feature (example: `InventoryToggle`, `PurchaseItem`).
- Keep validation and anti-exploit checks on the server.
- Never trust client values directly.

## 7) Update mappings if you add top-level folders

Your current `default.project.json` mapping is already valid for:

- `src/server`
- `src/client`
- `src/shared`

Only edit mappings if you need additional Roblox services.

## 8) Use this test loop every time

1. Save file in VS Code.
2. Confirm Rojo is still connected.
3. Press Play in Studio.
4. Check Output for errors.
5. Fix immediately before moving on.

## 9) Commit checkpoints often

Use small commits like:

```powershell
git add .
git commit -m "Migrate inventory controllers and server handlers"
```

## 10) First real milestone target

Complete one full feature end-to-end:

- Client input/UI
- Remote event/function
- Server validation + state update
- Shared config/module

When one feature is stable, start the next.

---

## Quick troubleshooting

### Only client logs appear

- In Output, switch to Server or All.
- Open F9 Developer Console and check Server tab.
- Ensure script is under `ServerScriptService > Server` and is a `Script`.

### Changes do not sync

- Confirm `rojo serve` is running.
- Reconnect plugin to `localhost:34872`.
- Restart serve if you edited `default.project.json`.

### Requires fail after migration

- Re-check module paths after moving files.
- Migrate one feature at a time to isolate breakage.

---

If you want, the next step is to scaffold all folders and starter module files automatically in this project.