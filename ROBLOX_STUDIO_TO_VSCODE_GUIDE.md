# Import a Roblox Studio Project into VS Code

This guide shows the most reliable workflow in 2026: **Rojo + Roblox Studio + VS Code**.

## What this gives you

- Your scripts and project files live in VS Code
- Roblox Studio stays connected for playtesting
- You can use Git, extensions, formatting, and search in a normal code editor workflow

---

## 1) Install prerequisites

1. Install **Roblox Studio** (if not already installed).
2. Install **VS Code**.
3. Install **Rojo CLI** on Windows (choose one method):

### Option A: winget

```powershell
winget install Rojo.Rojo
```

### Option B: Chocolatey

```powershell
choco install rojo
```

4. Verify Rojo is installed:

```powershell
rojo --version
```

If you see a version number, you are good.

---

## 2) Install the Rojo plugin in Roblox Studio

1. Open Roblox Studio.
2. Open the **Toolbox** and switch to **Marketplace** plugins.
3. Search for **Rojo** and install the official plugin.
4. Restart Studio if prompted.

---

## 3) Create your local project folder

From your project folder in VS Code terminal:

```powershell
cd "e:\BuildAClub"
rojo init
```

This creates a starter Rojo setup (including `default.project.json` and a `src` folder).

---

## 4) Open the place you want to migrate

1. In Roblox Studio, open your existing place (`.rbxl`/`.rbxlx`) or Team Create place.
2. Save a backup copy before migration.

---

## 5) Connect Studio to VS Code with Rojo

1. In VS Code terminal, run:

```powershell
cd "e:\BuildAClub"
rojo serve
```

2. Keep that terminal running.
3. In Roblox Studio, open the **Rojo** plugin.
4. Connect to `localhost` on port `34872` (default Rojo serve port).

If connected, Studio can sync with your filesystem project.

---

## 6) Move scripts from Studio into your `src` folder

There are two common migration approaches:

### Approach A (recommended): Recreate structure in `src` and paste scripts

1. In VS Code, mirror important containers in `src` (for example `ReplicatedStorage`, `ServerScriptService`, `StarterPlayerScripts`).
2. Create `.lua`/`.luau` files for each script.
3. Copy code from Studio scripts into those files.
4. Save files; Rojo sync updates back to Studio when connected.

### Approach B: Use Rojo plugin export/import utilities (if available in your plugin version)

Some Rojo plugin versions provide actions to help generate or map filesystem structure from the live place. If present, use those commands, then clean up folder names and mappings in `default.project.json`.

---

## 7) Map services correctly in `default.project.json`

Edit mappings so folders in `src` point to the right Roblox services.

Example shape (adjust to your game):

```json
{
  "name": "BuildAClub",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$path": "src/ReplicatedStorage"
    },
    "ServerScriptService": {
      "$path": "src/ServerScriptService"
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      }
    }
  }
}
```

After editing, restart `rojo serve` if needed.

---

## 8) Recommended VS Code extensions

Install these for a better Roblox workflow:

- Roblox LSP (Luau language support)
- Luau syntax/highlighting extension
- EditorConfig
- Prettier or Stylua-compatible formatter (if your team uses one)

---

## 9) Confirm sync works

1. With `rojo serve` running, edit a script file in VS Code.
2. Check the same script in Studio.
3. Make a small change in Studio (if your sync mode supports it) and verify expected behavior.

If one-way sync is configured, keep VS Code as source of truth.

---

## 10) Add Git (strongly recommended)

In VS Code terminal:

```powershell
cd "e:\BuildAClub"
git init
git add .
git commit -m "Initial Rojo project import"
```

Create a `.gitignore` for generated/temp files if needed.

---

## Troubleshooting

### `rojo` command not found

- Restart terminal/VS Code after install.
- Confirm install path is in `PATH`.
- Re-run `rojo --version`.

### Studio cannot connect to Rojo

- Ensure `rojo serve` is running.
- Check port `34872` is not blocked by firewall.
- Verify plugin is connected to `localhost`.

### Scripts not appearing where expected

- Fix mappings in `default.project.json`.
- Ensure folder names match Roblox service names exactly.
- Restart serve session after mapping changes.

### Team Create conflicts

- Decide whether Studio or filesystem is source of truth.
- For code, prefer filesystem (VS Code + Git) to avoid merge confusion.

---

## Daily workflow

1. Open VS Code project.
2. Run `rojo serve`.
3. Open place in Studio and connect Rojo plugin.
4. Edit code in VS Code.
5. Test in Studio.
6. Commit changes to Git.

That is the full setup to effectively "import" your Roblox Studio project into VS Code and keep it synced.