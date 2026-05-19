# JARVIS Workspace — New User Guide

Welcome! JARVIS Workspace is a one-click virtual desktop & app launcher for Windows 10/11. This guide walks you through your **first-time setup** and **first launch**.

**One-click virtual desktop & app launcher for Windows 10/11**

[![Release](https://img.shields.io/github/v/release/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-?color=blue&label=Latest%20Release)](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?logo=windows)](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/releases/latest)


<br/>

> Define your workspace once. Launch everything with one click.

<br/>

[**Download v1.0.0**](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/releases/latest) &nbsp;·&nbsp; [Source Code](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/tree/version-1.0.0) &nbsp;·&nbsp; [Report a Bug](https://github.com/hassanramzan11/Jarvis-Workspace/issues)

</div>

---

## Step 1 — Install the App

1. Download the latest release zip.
2. Extract the folder anywhere on your PC.
3. Double-click **`Install.bat`**.
4. If Windows shows a SmartScreen warning, click **More info → Run anyway**.

The installer automatically:
- Copies files to `%USERPROFILE%\AppData\Local\JarvisTools\`
- Downloads `VirtualDesktop.exe` (used to manage virtual desktops)
- Adds a **Desktop shortcut** and **Start Menu entry** named "JARVIS Workspace"
- Installs an uninstaller

When it finishes, you can launch JARVIS from your Desktop or Start Menu.

---

## Step 2 — Open JARVIS for the First Time

Double-click the **JARVIS Workspace** shortcut on your Desktop.

You'll see a GUI with two main sections:
- **Profile selector** (top) — switch between saved workspace layouts
- **Desktops & apps** (main area) — define what your workspace looks like

---

## Step 3 — Create Your First Profile

1. Click **New Profile** and give it a name (e.g. *Work*, *Gaming*, *Study*).
2. For each virtual desktop you want, click **Add Desktop** and name it — for example:
   - **Desktop 1:** Office (Outlook, Word, Excel)
   - **Desktop 2:** Code (VS Code, Terminal, Browser)
   - **Desktop 3:** Personal (Spotify, WhatsApp)
3. **Drag and drop** your app shortcuts into each desktop. You can drag:
   - `.lnk` shortcuts from your Desktop or Start Menu
   - `.exe` files directly
   - `.url` web shortcuts (open a website on launch)
4. Click **SAVE PROFILE**.

> Tip: Right-click any app in the list to remove it or change its launch order.
1. Go to the [**Releases page**](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/releases/latest)
2. Download **`JarvisWorkspace-Setup-1.0.0.exe`**
3. Run the installer — if Windows shows a SmartScreen warning, click **More info → Run anyway**
4. A shortcut named **JARVIS Workspace** will appear on your Desktop and Start Menu

---

## Step 4 — Launch Your Workspace

Click the big **LET'S COOK** button.

JARVIS will:
1. Create the named virtual desktops in order
2. Switch to each desktop and launch its apps
3. Return you to the first desktop, ready to work

That's it — your full environment is set up in seconds.

---

## Where Your Data Lives

| What | Location |
|------|----------|
| Profiles | `%APPDATA%\JarvisWorkspace\profiles\*.json` |
| Installed app files | `%USERPROFILE%\AppData\Local\JarvisTools\` |

Profiles are plain JSON — you can back them up, share them, or edit them by hand.

---

## Uninstalling

Run **`Uninstall.bat`** from the install folder.
Your profiles in `%APPDATA%\JarvisWorkspace\` are kept so you can reinstall later without losing your setup.

---

## Troubleshooting (First-Time Issues)

- **"Windows protected your PC" popup** — click *More info → Run anyway*. The installer is unsigned but safe.
- **Virtual desktops not switching** — make sure you're on Windows 10 build 1809+ or Windows 11.
- **An app didn't launch** — check that the shortcut path still exists; re-add it if needed.
The full source is available on the [`version-1.0.0`](https://github.com/hassanramzan11/J.A.R.V.I.S-Workspace-PowerShell-based-App-/tree/version-1.0.0) branch.

---

## Need Help?

Open an issue on the project repo, or check the existing profiles in `%APPDATA%\JarvisWorkspace\profiles\` for examples.

Built by Saad with help from Claude.
