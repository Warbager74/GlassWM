#!/usr/bin/env bash
set -e

echo "[*] Initializing GlassWM Project Workspace..."
mkdir -p glasswm/{src,dotfiles/rofi}
cd glasswm

# 1. Write Cargo.toml
cat << 'EOF' > Cargo.toml
[package]
name = "glasswm"
version = "0.1.0"
edition = "2021"

[dependencies]
x11rb = { version = "0.13", features = ["all"] }
serde = { version = "1.0", features = ["derive"] }
toml = "0.8"
dirs = "5.0"
shellexpand = "3.1"
EOF

# 2. Write src/config.rs
cat << 'EOF' > src/config.rs
use serde::Deserialize;
use std::fs;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub border_width: u32,
    pub border_color_active: u32,
    pub border_color_inactive: u32,
    pub terminal: String,
    pub launcher: String,
    pub autostart_script: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            border_width: 2,
            border_color_active: 0x89b4fa,
            border_color_inactive: 0x313244,
            terminal: "alacritty".to_string(),
            launcher: "rofi -show drun".to_string(),
            autostart_script: "~/.config/glasswm/autostart.sh".to_string(),
        }
    }
}

impl Config {
    pub fn load() -> Self {
        if let Some(mut path) = dirs::config_dir() {
            path.push("glasswm/config.toml");
            if let Ok(contents) = fs::read_to_string(&path) {
                if let Ok(parsed) = toml::from_str(&contents) {
                    return parsed;
                }
            }
        }
        Config::default()
    }
}
EOF

# 3. Write src/main.rs
cat << 'EOF' > src/main.rs
mod config;
use config::Config;
use std::collections::HashMap;
use std::process::Command;
use x11rb::connection::Connection;
use x11rb::protocol::xproto::*;
use x11rb::protocol::Event;
use x11rb::rust_connection::RustConnection;

struct DragState {
    window: Window,
    start_mouse: (i16, i16),
    start_geom: (i16, i16, u16, u16),
    is_resize: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cfg = Config::load();
    let (conn, screen_num) = RustConnection::connect(None)?;
    let screen = &conn.setup().roots[screen_num];
    let root = screen.root;

    let expanded_autostart = shellexpand::tilde(&cfg.autostart_script).to_string();
    if std::path::Path::new(&expanded_autostart).exists() {
        let _ = Command::new("bash").arg(expanded_autostart).spawn();
    }

    let change_values = ChangeWindowAttributesAux::default()
        .event_mask(EventMask::SUBSTRUCTURE_REDIRECT | EventMask::SUBSTRUCTURE_NOTIFY);

    if conn.change_window_attributes(root, &change_values)?.check().is_err() {
        eprintln!("Error: Another Window Manager is already running!");
        return Ok(());
    }

    let mod_super = ModMask::M4;
    conn.grab_button(false, root, EventMask::BUTTON_PRESS | EventMask::BUTTON_RELEASE | EventMask::POINTER_MOTION, GrabMode::ASYNC, GrabMode::ASYNC, 0, 0, ButtonIndex::M1, mod_super)?;
    conn.grab_button(false, root, EventMask::BUTTON_PRESS | EventMask::BUTTON_RELEASE | EventMask::POINTER_MOTION, GrabMode::ASYNC, GrabMode::ASYNC, 0, 0, ButtonIndex::M3, mod_super)?;

    let min_kc = conn.setup().min_keycode;
    let max_kc = conn.setup().max_keycode;
    let mapping = conn.get_keyboard_mapping(min_kc, max_kc - min_kc + 1)?.reply()?;
    let per_kc = mapping.keysyms_per_keycode as usize;

    let find_keycode = |sym: u32| -> Option<u8> {
        for (idx, keysyms) in mapping.keysyms.chunks(per_kc).enumerate() {
            if keysyms.contains(&sym) { return Some(min_kc + idx as u8); }
        }
        None
    };

    let kc_return = find_keycode(0xff0d).unwrap_or(36);
    let kc_space = find_keycode(0x0020).unwrap_or(65);
    let kc_q = find_keycode(0x0071).unwrap_or(24);
    let kc_e = find_keycode(0x0065).unwrap_or(26);

    conn.grab_key(false, root, mod_super, kc_return, GrabMode::ASYNC, GrabMode::ASYNC)?;
    conn.grab_key(false, root, mod_super, kc_space, GrabMode::ASYNC, GrabMode::ASYNC)?;
    conn.grab_key(false, root, mod_super, kc_q, GrabMode::ASYNC, GrabMode::ASYNC)?;
    conn.grab_key(false, root, mod_super | ModMask::SHIFT, kc_e, GrabMode::ASYNC, GrabMode::ASYNC)?;
    conn.flush()?;

    let mut drag: Option<DragState> = None;
    let mut managed_windows: HashMap<Window, ()> = HashMap::new();

    loop {
        let event = conn.wait_for_event()?;
        match event {
            Event::MapRequest(ev) => {
                let attrs = conn.get_window_attributes(ev.window)?.reply()?;
                if attrs.override_redirect {
                    let _ = conn.map_window(ev.window);
                    continue;
                }
                managed_windows.insert(ev.window, ());
                let aux = ChangeWindowAttributesAux::default()
                    .border_pixel(cfg.border_color_active)
                    .event_mask(EventMask::ENTER_WINDOW | EventMask::FOCUS_CHANGE);
                let _ = conn.change_window_attributes(ev.window, &aux);
                let _ = conn.configure_window(ev.window, &ConfigureWindowAux::default().border_width(cfg.border_width));
                let _ = conn.map_window(ev.window);
                let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, ev.window, x11rb::CURRENT_TIME);
                conn.flush()?;
            }
            Event::ConfigureRequest(ev) => {
                let mut aux = ConfigureWindowAux::default();
                if ev.value_mask & u16::from(ConfigWindow::X) != 0 { aux = aux.x(ev.x as i32); }
                if ev.value_mask & u16::from(ConfigWindow::Y) != 0 { aux = aux.y(ev.y as i32); }
                if ev.value_mask & u16::from(ConfigWindow::WIDTH) != 0 { aux = aux.width(ev.width as u32); }
                if ev.value_mask & u16::from(ConfigWindow::HEIGHT) != 0 { aux = aux.height(ev.height as u32); }
                if ev.value_mask & u16::from(ConfigWindow::BORDER_WIDTH) != 0 { aux = aux.border_width(cfg.border_width); }
                let _ = conn.configure_window(ev.window, &aux);
                conn.flush()?;
            }
            Event::DestroyNotify(ev) => { managed_windows.remove(&ev.window); }
            Event::ButtonPress(ev) => {
                if ev.child != 0 && ev.child != root {
                    let geom = conn.get_geometry(ev.child)?.reply()?;
                    drag = Some(DragState {
                        window: ev.child,
                        start_mouse: (ev.root_x, ev.root_y),
                        start_geom: (geom.x, geom.y, geom.width, geom.height),
                        is_resize: ev.detail == ButtonIndex::M3.into(),
                    });
                    let _ = conn.configure_window(ev.child, &ConfigureWindowAux::default().stack_mode(StackMode::ABOVE));
                    let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, ev.child, x11rb::CURRENT_TIME);
                    conn.flush()?;
                }
            }
            Event::MotionNotify(ev) => {
                if let Some(ref d) = drag {
                    let dx = ev.root_x - d.start_mouse.0;
                    let dy = ev.root_y - d.start_mouse.1;
                    if d.is_resize {
                        let new_w = (d.start_geom.2 as i32 + dx as i32).max(100) as u32;
                        let new_h = (d.start_geom.3 as i32 + dy as i32).max(80) as u32;
                        let _ = conn.configure_window(d.window, &ConfigureWindowAux::default().width(new_w).height(new_h));
                    } else {
                        let new_x = d.start_geom.0 as i32 + dx as i32;
                        let new_y = d.start_geom.1 as i32 + dy as i32;
                        let _ = conn.configure_window(d.window, &ConfigureWindowAux::default().x(new_x).y(new_y));
                    }
                    conn.flush()?;
                }
            }
            Event::ButtonRelease(_) => { drag = None; }
            Event::KeyPress(ev) => {
                if ev.detail == kc_return {
                    let _ = Command::new(&cfg.terminal).spawn();
                } else if ev.detail == kc_space {
                    let parts: Vec<&str> = cfg.launcher.split_whitespace().collect();
                    if !parts.is_empty() { let _ = Command::new(parts[0]).args(&parts[1..]).spawn(); }
                } else if ev.detail == kc_q {
                    if let Ok(focus) = conn.get_input_focus()?.reply() {
                        if focus.focus != root && focus.focus != 0 { let _ = conn.kill_client(focus.focus); }
                    }
                } else if ev.detail == kc_e && (ev.state & u16::from(ModMask::SHIFT)) != 0 {
                    break;
                }
            }
            _ => {}
        }
    }
    Ok(())
}
EOF

# 4. Copy dotfiles and desktop configurations
cat << 'EOF' > dotfiles/config.toml
border_width = 2
border_color_active = 0x89b4fa
border_color_inactive = 0x313244
terminal = "alacritty"
launcher = "rofi -show drun -theme ~/.config/glasswm/rofi/config.rasi"
autostart_script = "~/.config/glasswm/autostart.sh"
EOF

cat << 'EOF' > dotfiles/picom.conf
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;
blur: {
  method = "dual_kawase";
  strength = 7;
  background = true;
  background-frame = true;
  background-fixed = false;
}
corner-radius = 16;
shadow = true;
shadow-radius = 24;
shadow-opacity = 0.35;
shadow-offset-x = -18;
shadow-offset-y = -18;
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 5;
opacity-rule = [
  "88:class_g = 'Rofi'",
  "85:class_g = 'Alacritty'",
  "85:class_g = 'kitty'",
  "92:class_g = 'Polybar'"
];
EOF

cat << 'EOF' > dotfiles/polybar.ini
[bar/top]
width = 100%
height = 30pt
fixed-center = true
background = #99121218
foreground = #e6edf3
padding-left = 2
padding-right = 2
module-margin = 2
font-0 = "JetBrainsMono Nerd Font:size=11;3"
font-1 = "JetBrainsMono Nerd Font:style=Bold:size=11;3"
font-2 = "JetBrainsMono Nerd Font:size=14;4"
modules-left = mac-logo xwindow
modules-center = date
modules-right = pulseaudio
cursor-click = pointer
override-redirect = true

[module/mac-logo]
type = custom/text
content = ""
content-font = 3
content-foreground = #ffffff
content-padding = 1
click-left = rofi -show drun -theme ~/.config/glasswm/rofi/config.rasi

[module/xwindow]
type = internal/xwindow
label = %title:0:30:...%
label-foreground = #c9d1d9

[module/date]
type = internal/date
interval = 1
date = "%a %b %d  %I:%M %p"
label = %date%
label-font = 2
label-foreground = #ffffff

[module/pulseaudio]
type = internal/pulseaudio
label-volume = "󰕾 %percentage%%"
label-muted = "󰝟 muted"
label-muted-foreground = #768390
EOF

cat << 'EOF' > dotfiles/rofi/config.rasi
configuration {
    modi: "drun";
    show-icons: true;
    display-drun: "";
    drun-display-format: "{name}";
    font: "JetBrainsMono Nerd Font 10.5";
}
* {
    bg-color: rgba(25, 27, 36, 0.85);
    input-bg: rgba(255, 255, 255, 0.08);
    border-color: rgba(255, 255, 255, 0.15);
    selected-color: rgba(255, 255, 255, 0.12);
    fg-color: #f0f6fc;
    fg-dim: #8b949e;
}
window {
    transparency: "real";
    location: center;
    anchor: center;
    width: 640px;
    height: 520px;
    border: 1px;
    border-color: @border-color;
    border-radius: 18px;
    background-color: @bg-color;
}
mainbox {
    background-color: transparent;
    padding: 28px;
    children: [ inputbar, listview ];
}
inputbar {
    background-color: @input-bg;
    border: 1px;
    border-color: @border-color;
    border-radius: 25px;
    padding: 10px 18px;
    margin: 0px 0px 24px 0px;
    children: [ prompt, entry ];
}
prompt { background-color: transparent; text-color: @fg-dim; padding: 0px 10px 0px 0px; }
entry { background-color: transparent; text-color: @fg-color; placeholder: "Type here to search..."; placeholder-color: @fg-dim; }
listview {
    columns: 5;
    lines: 4;
    cycle: true;
    scrollbar: false;
    layout: vertical;
    spacing: 16px;
    background-color: transparent;
}
element {
    orientation: vertical;
    border-radius: 12px;
    padding: 14px 6px;
    background-color: transparent;
    text-color: @fg-color;
}
element-icon { size: 44px; horizontal-align: 0.5; background-color: transparent; }
element-text { horizontal-align: 0.5; text-color: @fg-color; margin: 8px 0px 0px 0px; background-color: transparent; }
element selected { background-color: @selected-color; border: 1px; border-color: @border-color; }
EOF

cat << 'EOF' > dotfiles/autostart.sh
#!/usr/bin/env bash
killall -q picom polybar
feh --bg-fill ~/.config/glasswm/wallpaper.jpg 2>/dev/null || xsetroot -solid "#12141c"
picom --config ~/.config/glasswm/picom.conf &
polybar -c ~/.config/glasswm/polybar.ini top &
EOF
chmod +x dotfiles/autostart.sh

cat << 'EOF' > glasswm.desktop
[Desktop Entry]
Name=GlassWM
Comment=Independent modern X11 window manager with liquid glass aesthetic
Exec=glasswm
Type=XSession
DesktopNames=GlassWM
EOF

cat << 'EOF' > PKGBUILD
pkgname=glasswm
pkgver=1.0.0
pkgrel=1
pkgdesc="Independent modern X11 window manager with liquid glass aesthetics"
arch=('x86_64')
url="https://github.com/local/glasswm"
license=('MIT')
depends=('libxcb' 'picom' 'rofi' 'polybar' 'feh' 'ttf-jetbrains-mono-nerd' 'alacritty')
makedepends=('rust' 'cargo')
source=()

build() {
  cargo build --release --locked
}

package() {
  install -Dm755 "target/release/glasswm" "$pkgdir/usr/bin/glasswm"
  install -Dm644 "glasswm.desktop" "$pkgdir/usr/share/xsessions/glasswm.desktop"
  install -d "$pkgdir/etc/skel/.config/glasswm/rofi"
  install -Dm644 "dotfiles/config.toml" "$pkgdir/etc/skel/.config/glasswm/config.toml"
  install -Dm644 "dotfiles/picom.conf" "$pkgdir/etc/skel/.config/glasswm/picom.conf"
  install -Dm644 "dotfiles/polybar.ini" "$pkgdir/etc/skel/.config/glasswm/polybar.ini"
  install -Dm644 "dotfiles/rofi/config.rasi" "$pkgdir/etc/skel/.config/glasswm/rofi/config.rasi"
  install -Dm755 "dotfiles/autostart.sh" "$pkgdir/etc/skel/.config/glasswm/autostart.sh"
}
EOF

# Copy config files to active user home directly so it is ready right away
mkdir -p ~/.config/glasswm/rofi
cp dotfiles/config.toml ~/.config/glasswm/
cp dotfiles/picom.conf ~/.config/glasswm/
cp dotfiles/polybar.ini ~/.config/glasswm/
cp dotfiles/rofi/config.rasi ~/.config/glasswm/rofi/
cp dotfiles/autostart.sh ~/.config/glasswm/

echo "[*] Building and Installing via makepkg..."
makepkg -si --noconfirm

echo "[✔] Installation Complete! GlassWM is ready to use."
