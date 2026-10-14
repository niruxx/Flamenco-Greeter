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
- **Extra PAM prompts.** One-time codes, token PINs and fingerprint messages appear in the password field.

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

In preview, any password except `wrong` "logs in" (it prints the session it would have started), and the power buttons only log what they would do. The preview can also be driven over IPC:

```sh
qs -p greeter ipc call greeter menu users      # or: sessions, ""
qs -p greeter ipc call greeter type hunter2
qs -p greeter ipc call greeter submit
```

### Layout

```
bin/flamenco-greeter        launcher (run by greetd), sync, enable, preview, doctor,
                            and the users/sessions listings the UI reads
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
3. The UI loads users and sessions from `flamenco-greeter users|sessions --json`, preselects the remembered ones, and talks to greetd through `Quickshell.Services.Greetd`.
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
