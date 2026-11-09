# Faster file performance on Windows with WSL

WSL version 3.0.3 on Windows 10 gives you a major advantage: modern WSL fully supports VirtioFS. Microsoft separated the WSL kernel architecture from the Windows release cycle, which means newer WSL app-store builds can use high-performance features that were previously unavailable.

Enabling VirtioFS and making a few small configuration changes will give your `/mnt/c/` access path the best possible speed.

## Step 1: Enable VirtioFS in `.wslconfig`

VirtioFS replaces the older, slower Plan 9 file-sharing protocol with a direct virtualized shared-memory architecture.

1. Open File Explorer and go to your Windows user profile folder: `C:\Users\<Your-Windows-Username>`.
2. Look for a file named `.wslconfig`. If it does not exist, create a new text file and rename it to `.wslconfig` exactly. Make sure it does not end with `.txt`.
3. Open it in Notepad and add the following:

```ini
[wsl2]
virtiofs=true
```

4. Save the file.
5. Open Windows PowerShell and restart WSL to apply the change:

```powershell
wsl --shutdown
```

## Step 2: Optimize `/etc/wsl.conf` inside Debian

Now configure Debian so it does not track metadata every time your PHP or Laravel app touches a file in `/mnt/c/`.

1. Open a WSL Debian terminal and edit the configuration file:

```bash
sudo nano /etc/wsl.conf
```

2. Paste in this configuration:

```ini
[automount]
enabled = true
options = "metadata,noatime,uid=1000,gid=1000,umask=022"
```

- `noatime`: Prevents Linux from writing a read timestamp to the Windows SSD every time your app opens a config or script file.
- `metadata`: Lets you run `chmod` and `chown` natively on Windows files from your Debian CLI.

3. Press `Ctrl + O`, then `Enter` to save, and `Ctrl + X` to exit.

## Step 3: Whitelist the Windows project folder in Defender

Even with VirtioFS enabled, Windows Defender's real-time scanning can still interrupt a rapid file stream when it detects a workload touching the `C:` drive.

1. Open the Windows Start menu and launch Windows Security.
2. Go to **Virus & threat protection** → **Manage settings**.
3. Scroll down to **Exclusions** and click **Add or remove exclusions**.
4. Select **Add an exclusion** → **Folder**, then choose your app root, such as `C:\projects`.
