# Vendor binaries

Drop the following files from MScholtes' VirtualDesktop releases here before compiling the installer.

Download page: https://github.com/MScholtes/VirtualDesktop/releases

Required files (extract the `.exe` from each zip and rename if needed):

| File name in this folder    | Source zip                       | Target Windows version |
|-----------------------------|----------------------------------|------------------------|
| `VirtualDesktop11-24H2.exe` | `VirtualDesktop11-24H2.zip`      | Win 11 24H2 / 25H2 (build ≥ 26100) |
| `VirtualDesktop11-23H2.exe` | `VirtualDesktop11-23H2.zip`      | Win 11 23H2 (build 22631) |
| `VirtualDesktop11-22H2.exe` | `VirtualDesktop11-22H2.zip`      | Win 11 22H2 (build 22621) |
| `VirtualDesktop11.exe`      | `VirtualDesktop11.zip`           | Win 11 21H2 (build 22000) |
| `VirtualDesktop.exe`        | `VirtualDesktop.zip`             | Windows 10 |

The installer auto-detects the target machine's Windows build at install time and copies the matching binary to `%LOCALAPPDATA%\JarvisTools\VirtualDesktop.exe`, which is the exact path `Jarvis_Builder.ps1` expects.

If a file is missing the installer build will abort with an error pointing back here.
