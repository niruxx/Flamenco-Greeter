# 💃 Flamenco Greeter

A [greetd](https://sr.ht/~kennylevinsen/greetd/) login screen for [Flamenco Shell](https://github.com/niruxx/flamenco-shell). It's built from the same pieces as the shell's lock screen (same Theme, palettes, fonts, controls and motion), so logging in, locking and unlocking all look like one screen.

It follows the model of [DMS greeter](https://github.com/AvengeMedia/dank-greeter): a small Quickshell UI that greetd runs inside a minimal compositor, plus a `sync` command that copies your theme, wallpaper and avatar somewhere the greeter user can read them.

## ✨ Features

- **Your theme on the login screen.** Palette (including colors from the wallpaper), light/dark mode, accent, roundness, fonts, wallpaper and avatar all come from your Flamenco settings.
- **Same layout as the lock screen.** Clock, avatar, password pill with animated dots, shake on a wrong password, and power buttons along the bottom.
- **Multiple users.** A user picker with avatars, plus "Other user…" for typing a name. Each synced user brings their own theme, and the screen cross-fades when you switch between them.
- **Session chooser.** Lists every installed Wayland session, and X11 sessions when `startx` is available.
- **Remembers you.** The last user and session are preselected next time. Turn this off with `--no-save-username` / `--no-save-session`.
- **Your keyboard and cursor.** Keyboard layout, options, repeat rate, numlock and cursor theme are applied to the greeter's compositor, so typing your password works as it does on the desktop.
- **niri, Hyprland or sway.** The compositor config is generated at startup. Monitor layout can go in `/etc/greetd/flamenco-niri.kdl`.
- **Multi-monitor.** Every screen gets the wallpaper and clock. The first screen gets the login card.
- **Fingerprint login.** With fprintd, the reader starts listening as soon as a user with enrolled fingers is picked, and the field says "Scan your finger on the reader". Typing a password still works at any time, with no waiting for the scan to time out.
- **Extra PAM prompts.** One-time codes and token PINs appear in the password field.

## 🚀 Install

### Arch Linux (from this checkout)

```sh
cd packaging/arch && makepkg -si
```

This depends on `flamenco-shell`, `greetd` and `quickshell`. Pacman's systemd hooks create the `greeter` user and `/var/cache/flamenco-greeter`.

### Manual

```sh
sudo make install                 # installs to /usr
sudo systemd-sysusers && sudo systemd-tmpfiles --create
```

If Flamenco Shell lives somewhere other than `/usr/share/flamenco-shell/shell`, pass `SHELL_DIR=/path/to/flamenco-shell/shell`.

### Turn it on

```sh
flamenco-greeter preview   # optional: try it in a window first
flamenco-greeter enable    # writes /etc/greetd/config.toml and enables greetd (asks first)
flamenco-greeter sync      # copies your theme, wallpaper and avatar
flamenco-greeter doctor    # checks everything is in place
```

`enable` takes a compositor: `flamenco-greeter enable hyprland`. To set greetd up by hand instead, see [examples/config.toml](examples/config.toml).

## 🎨 Keeping it in sync

Run `flamenco-greeter sync` after changing your theme or wallpaper. It asks for sudo unless you're in the `greeter` group.

To have the login screen follow changes automatically:

```sh
sudo usermod -aG greeter $USER      # then log out and back in
systemctl --user enable --now flamenco-greeter-sync.path
```

The path unit re-syncs whenever `~/.config/flamenco/settings.json` changes. It never prompts for a password.

Only what the login screen needs is copied: appearance, wallpaper, avatar, clock format, keyboard layout and cursor. Shortcuts, autostart entries, your weather city and everything else stay in your home directory.

## 👆 Fingerprint login

```sh
sudo pacman -S fprintd
fprintd-enroll                      # enroll a finger for your user
flamenco-greeter fingerprint enable # adds pam_fprintd to /etc/pam.d/greetd (backed up first)
flamenco-greeter fingerprint status # reader, PAM and enrolled fingers at a glance
```

`flamenco-greeter enable` also offers this when it sees a reader. `fingerprint disable` removes the block again. If your PAM setup already has `pam_fprintd` (directly, or through an included file such as `system-auth`), it's detected and left alone.

How it behaves on the login screen:

- When a user is picked, the greeter opens a PAM session straight away. `pam_fprintd` checks, as root, whether that user has fingers enrolled. If they do, the reader starts and the field shows **"Scan your finger on the reader"**, with "or type your password" underneath. If they don't, it moves on to the password prompt, and nothing changes on screen.
- A finger that doesn't match shakes the field and shows "Fingerprint not recognized", but keeps whatever you've typed. After six misses the reader stops until the user is picked again, and only the password works.
- When a scan round times out, a new one starts, so the reader keeps listening while the screen sits idle.
- Pressing Enter on a typed password while the reader is listening briefly claims the reader for the greeter (`flamenco-greeter reader-hold`). `pam_fprintd` then can't use it, so it gives up immediately and the password goes straight through. If the reader can't be claimed, the password is held and sent as soon as the scan round ends (up to 30 s).

The greeter itself never asks fprintd about other users' fingers. That would need polkit's `setusername` right, which would also let the login screen enroll fingers for anyone. `pam_fprintd` does the checking instead.

## 🖥️ Monitors and compositor tweaks

The greeter compositor doesn't read your desktop config. For monitor layout or anything else niri-specific, create `/etc/greetd/flamenco-niri.kdl` ([example](examples/flamenco-niri.kdl)) and it will be included automatically. For Hyprland or sway, pass a base config with `-C`:

```toml
command = "/usr/bin/flamenco-greeter --command hyprland -C /etc/greetd/hypr-outputs.lua"
```

## 🛠️ Development

```sh
make dev        # link ../flamenco-shell/shell's Commons, Widgets and assets into ./greeter
make preview    # run the greeter in a window from this checkout (hot-reloads)
```

In preview, any password except `wrong` "logs in" (it prints the session it would have started), and the power buttons only log what they would do. `flamenco-greeter preview --fingerprint` adds a pretend reader. The preview can also be driven over IPC:

```sh
qs -p greeter ipc call greeter menu users      # or: sessions, ""
qs -p greeter ipc call greeter type hunter2
qs -p greeter ipc call greeter submit
qs -p greeter ipc call greeter finger true     # with --fingerprint: a matching (true) or wrong (false) finger
```

To build the Arch package into `History Builds/flamenco-greeter-<version>-<rel>/`, run `packaging/arch/build-local.sh`.

### Layout

```
bin/flamenco-greeter        launcher (run by greetd), sync, enable, fingerprint, preview, doctor,
                            plus the users/sessions/fingerprint probes and reader hold the UI uses
greeter/
  shell.qml                 entry point: layer-shell surfaces, or a window in preview
  Modules/Greeter/          GreeterContent (the screen), user/session menus, avatar
  Services/                 Greeter (greetd conversation + state), memory, power
  Commons/ Widgets/ assets/ ─┐ linked from Flamenco Shell, so Theme, Settings,
  Services/Time.qml        ─┘ palettes, fonts and controls are the shell's own
data/                       sysusers, tmpfiles, sync units
```

### How a login works

1. greetd starts `flamenco-greeter --command niri` as the `greeter` user.
2. The launcher copies the last user's synced `settings.json` to where the shell's `Settings` singleton reads it. It points `HOME` and the XDG directories into `/var/cache/flamenco-greeter`, writes a niri config with that user's keyboard layout and cursor, and starts niri. niri then starts `qs -p /usr/share/flamenco-greeter/greeter`.
3. The UI loads users, sessions and the fingerprint state from `flamenco-greeter users|sessions|fingerprint --json`, preselects the remembered ones, and talks to greetd through `Quickshell.Services.Greetd`. With fingerprint login on, it opens the PAM session right away so the reader can listen.
4. On success it saves the user and session, plays the lock screen's exit animation, and asks greetd to launch the session. Quickshell exits and niri quits.

### Data directory

```
/var/cache/flamenco-greeter/          greeter:greeter, 2770
  users/<name>/settings.json          written by `sync`
  users/<name>/wallpaper.*, face
  config/flamenco/settings.json       active theme (copied from a user slot at startup)
  state/memory.json                   last user + session
  state/niri.kdl                      generated compositor config
```
