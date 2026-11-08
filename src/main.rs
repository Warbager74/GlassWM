mod config;
use config::Config;

use std::collections::HashMap;
use std::fs;
use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};
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

fn query_wm_class<C: Connection>(conn: &C, window: Window) -> String {
    if let Ok(prop) = conn.get_property(false, window, AtomEnum::WM_CLASS, AtomEnum::STRING, 0, 1024) {
        if let Ok(reply) = prop.reply() {
            return String::from_utf8_lossy(&reply.value).to_lowercase();
        }
    }
    String::new()
}

fn find_toplevel_window<C: Connection>(
    conn: &C,
    root: Window,
    focused: Window,
    managed: &HashMap<Window, usize>,
) -> Option<Window> {
    if managed.contains_key(&focused) {
        return Some(focused);
    }
    let mut curr = focused;
    while curr != 0 && curr != root {
        if managed.contains_key(&curr) {
            return Some(curr);
        }
        if let Ok(tree) = conn.query_tree(curr) {
            if let Ok(reply) = tree.reply() {
                curr = reply.parent;
            } else {
                break;
            }
        } else {
            break;
        }
    }
    None
}

fn sort_windows_by_priority(
    windows: &[Window],
    classes: &HashMap<Window, String>,
) -> Vec<Window> {
    let mut wins = windows.to_vec();
    if wins.len() <= 1 {
        return wins;
    }

    let get_score = |win: &Window| -> u8 {
        if let Some(cls) = classes.get(win) {
            if cls.contains("kate") {
                3
            } else if cls.contains("firefox") {
                2
            } else if cls.contains("thunar") {
                1
            } else {
                0
            }
        } else {
            0
        }
    };

    let mut highest_idx = 0;
    let mut highest_score = 0;
    for (idx, w) in wins.iter().enumerate() {
        let score = get_score(w);
        if score > highest_score {
            highest_score = score;
            highest_idx = idx;
        }
    }

    let master = wins.remove(highest_idx);
    wins.insert(0, master);
    wins
}

fn retile_desktop<C: Connection>(
    conn: &C,
    screen_w: u32,
    screen_h: u32,
    cfg: &Config,
    windows: &[Window],
    classes: &HashMap<Window, String>,
) {
    if windows.is_empty() {
        return;
    }

    let sorted = sort_windows_by_priority(windows, classes);
    let count = sorted.len().min(4);

    let top_y = cfg.top_bar_height as i32 + cfg.window_gap as i32;
    let usable_h = screen_h.saturating_sub(cfg.top_bar_height + cfg.bottom_dock_height + (cfg.window_gap * 2));
    let usable_w = screen_w.saturating_sub(cfg.window_gap * 2);

    if count == 1 {
        let aux = ConfigureWindowAux::default()
            .x(cfg.window_gap as i32)
            .y(top_y)
            .width(usable_w.saturating_sub(cfg.border_width * 2))
            .height(usable_h.saturating_sub(cfg.border_width * 2))
            .border_width(cfg.border_width);
        let _ = conn.configure_window(sorted[0], &aux);
        return;
    }

    let master_w = (usable_w.saturating_sub(cfg.window_gap)) / 2;
    let stack_w = usable_w.saturating_sub(master_w + cfg.window_gap);
    let stack_x = cfg.window_gap as i32 + master_w as i32 + cfg.window_gap as i32;

    let master_aux = ConfigureWindowAux::default()
        .x(cfg.window_gap as i32)
        .y(top_y)
        .width(master_w.saturating_sub(cfg.border_width * 2))
        .height(usable_h.saturating_sub(cfg.border_width * 2))
        .border_width(cfg.border_width);
    let _ = conn.configure_window(sorted[0], &master_aux);

    let stack_count = (count - 1) as u32;
    let total_gaps = (stack_count - 1) * cfg.window_gap;
    let each_h = usable_h.saturating_sub(total_gaps) / stack_count;

    for i in 0..stack_count {
        let win = sorted[i as usize + 1];
        let win_y = top_y + (i * (each_h + cfg.window_gap)) as i32;
        let aux = ConfigureWindowAux::default()
            .x(stack_x)
            .y(win_y)
            .width(stack_w.saturating_sub(cfg.border_width * 2))
            .height(each_h.saturating_sub(cfg.border_width * 2))
            .border_width(cfg.border_width);
        let _ = conn.configure_window(win, &aux);
    }
}

fn switch_to_desktop<C: Connection>(
    conn: &C,
    target_desk: usize,
    current_desktop: &mut usize,
    desktops: &[Vec<Window>; 9],
    window_classes: &HashMap<Window, String>,
    active_window: &mut Window,
    screen_w: u32,
    screen_h: u32,
    cfg: &Config,
    root: Window,
) {
    if target_desk == *current_desktop || target_desk >= 9 {
        return;
    }

    for &win in &desktops[*current_desktop] {
        let _ = conn.unmap_window(win);
    }

    *current_desktop = target_desk;
    write_current_desktop(*current_desktop);

    for &win in &desktops[*current_desktop] {
        let _ = conn.map_window(win);
    }

    if let Some(&top_win) = desktops[*current_desktop].first() {
        *active_window = top_win;
        let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, top_win, x11rb::CURRENT_TIME);
        let _ = conn.change_window_attributes(top_win, &ChangeWindowAttributesAux::default().border_pixel(cfg.border_color_active));
    } else {
        *active_window = 0;
        let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, root, x11rb::CURRENT_TIME);
    }

    retile_desktop(conn, screen_w, screen_h, cfg, &desktops[*current_desktop], window_classes);
    update_desktop_file(*current_desktop, desktops);
    update_taskbar_file(&desktops[*current_desktop], window_classes, *active_window);
    let _ = conn.flush();
}

fn update_desktop_file(current_desktop: usize, desktops: &[Vec<Window>; 9]) {
    if let Some(mut path) = dirs::config_dir() {
        path.push("glasswm/desktop_polybar");
        let home = dirs::home_dir().map(|p| p.to_string_lossy().to_string()).unwrap_or_else(|| "~".to_string());
        let mut out = String::new();
        for i in 0..9 {
            let has_windows = !desktops[i].is_empty();
            let is_active = (i == current_desktop);
            let num = i + 1;
            let action = format!("{}/.config/glasswm/scripts/switch_desktop.sh {}", home, num);

            if is_active {
                out.push_str(&format!(
                    "%{{A1:{}:}}%{{B#8c7ae6}}%{{F#ffffff}}  {}  %{{F-}}%{{B-}}%{{A}} ",
                    action, num
                ));
            } else if has_windows {
                out.push_str(&format!(
                    "%{{A1:{}:}}%{{F#cdd6f4}}  {}  %{{F-}}%{{A}} ",
                    action, num
                ));
            } else {
                out.push_str(&format!(
                    "%{{A1:{}:}}%{{F#6c7086}}  {}  %{{F-}}%{{A}} ",
                    action, num
                ));
            }
        }
        let _ = fs::write(path, out);
    }
}

fn update_taskbar_file(
    windows: &[Window],
    classes: &HashMap<Window, String>,
    active_win: Window,
) {
    if let Some(mut path) = dirs::config_dir() {
        path.push("glasswm/tasks_polybar");
        let mut out = String::new();

        if windows.is_empty() {
            out.push_str("%{A1:firefox &:} 󰈹 %{A}   %{A1:thunar &:} 󰉋 %{A}   %{A1:kitty &:} 󰄛 %{A}   %{A1:code &:} 󰨞 %{A}   %{A1:spotify &:} 󰓇 %{A}");
        } else {
            for &w in windows {
                let cls = classes.get(&w).cloned().unwrap_or_else(|| "app".to_string());
                let (icon, label) = if cls.contains("kitty") || cls.contains("alacritty") {
                    ("󰄛", "Terminal")
                } else if cls.contains("firefox") {
                    ("󰈹", "Firefox")
                } else if cls.contains("thunar") || cls.contains("files") {
                    ("󰉋", "Files")
                } else if cls.contains("kate") {
                    ("󱞂", "Kate")
                } else if cls.contains("code") {
                    ("󰨞", "Code")
                } else if cls.contains("discord") {
                    ("󰙯", "Discord")
                } else if cls.contains("spotify") {
                    ("󰓇", "Spotify")
                } else {
                    ("󰣆", "Window")
                };

                let is_focused = (w == active_win);
                if is_focused {
                    out.push_str(&format!(
                        "%{{A1:xdotool windowactivate {}:}}%{{B#28ffffff}}%{{F#ffffff}}  {} {}  %{{F-}}%{{B-}}%{{A}}  ",
                        w, icon, label
                    ));
                } else {
                    out.push_str(&format!(
                        "%{{A1:xdotool windowactivate {}:}}%{{F#9399b2}}  {} {}  %{{F-}}%{{A}}  ",
                        w, icon, label
                    ));
                }
            }
        }
        let _ = fs::write(path, out);
    }
}

fn write_current_desktop(desktop: usize) {
    if let Some(mut path) = dirs::config_dir() {
        path.push("glasswm/current_desktop");
        let _ = fs::write(path, format!("{}", desktop + 1));
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cfg = Config::load();
    let (conn, screen_num) = RustConnection::connect(None)?;
    let screen = &conn.setup().roots[screen_num];
    let root = screen.root;

    let autostart_str = cfg.autostart_script.trim();
    let autostart_path = if let Some(stripped) = autostart_str.strip_prefix("~/") {
        dirs::home_dir()
            .map(|h| h.join(stripped))
            .unwrap_or_else(|| std::path::PathBuf::from(autostart_str))
    } else {
        std::path::PathBuf::from(autostart_str)
    };

    if autostart_path.exists() {
        let _ = Command::new("bash").arg(autostart_path).spawn();
    }

    let change_values = ChangeWindowAttributesAux::default()
        .event_mask(EventMask::SUBSTRUCTURE_REDIRECT | EventMask::SUBSTRUCTURE_NOTIFY | EventMask::BUTTON_PRESS);

    if conn.change_window_attributes(root, &change_values)?.check().is_err() {
        eprintln!("Error: Another Window Manager is already running!");
        return Ok(());
    }

    let mod_super = ModMask::M4;
    let mod_super_shift = ModMask::M4 | ModMask::SHIFT;

    let clean_masks = [
        0u16,
        u16::from(ModMask::M2),
        u16::from(ModMask::LOCK),
        u16::from(ModMask::M2) | u16::from(ModMask::LOCK),
    ];

    for &extra in &clean_masks {
        let m_super: ModMask = (u16::from(mod_super) | extra).into();
        conn.grab_button(false, root, EventMask::BUTTON_PRESS | EventMask::BUTTON_RELEASE | EventMask::POINTER_MOTION, GrabMode::ASYNC, GrabMode::ASYNC, 0u32, 0u32, ButtonIndex::M1, m_super)?;
        conn.grab_button(false, root, EventMask::BUTTON_PRESS | EventMask::BUTTON_RELEASE | EventMask::POINTER_MOTION, GrabMode::ASYNC, GrabMode::ASYNC, 0u32, 0u32, ButtonIndex::M3, m_super)?;
    }

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

    let kc_super_l = find_keycode(0xffeb);
    let kc_super_r = find_keycode(0xffec);
    let kc_return = find_keycode(0xff0d).unwrap_or(36);
    let kc_q = find_keycode(0x0071).unwrap_or(24);
    let kc_w = find_keycode(0x0077).unwrap_or(25);
    let kc_e = find_keycode(0x0065).unwrap_or(26);
    let kc_f = find_keycode(0x0066).unwrap_or(41); // 'f' key for Win + F

    let no_mods: ModMask = 0u16.into();
    if let Some(kc) = kc_super_l { conn.grab_key(false, root, no_mods, kc, GrabMode::ASYNC, GrabMode::ASYNC)?; }
    if let Some(kc) = kc_super_r { conn.grab_key(false, root, no_mods, kc, GrabMode::ASYNC, GrabMode::ASYNC)?; }

    for &extra in &clean_masks {
        let m_super: ModMask = (u16::from(mod_super) | extra).into();
        let m_shift: ModMask = (u16::from(mod_super_shift) | extra).into();
        conn.grab_key(false, root, m_super, kc_q, GrabMode::ASYNC, GrabMode::ASYNC)?;
        conn.grab_key(false, root, m_shift, kc_q, GrabMode::ASYNC, GrabMode::ASYNC)?;
        conn.grab_key(false, root, m_super, kc_return, GrabMode::ASYNC, GrabMode::ASYNC)?;
        conn.grab_key(false, root, m_super, kc_w, GrabMode::ASYNC, GrabMode::ASYNC)?;
        conn.grab_key(false, root, m_super, kc_f, GrabMode::ASYNC, GrabMode::ASYNC)?; // Win + F
        conn.grab_key(false, root, m_shift, kc_e, GrabMode::ASYNC, GrabMode::ASYNC)?;
    }

    let mut desktop_keycodes = Vec::new();
    for i in 1..=9 {
        let kc = find_keycode(0x0030 + i as u32).unwrap_or(9 + i as u8);
        for &extra in &clean_masks {
            let m_super: ModMask = (u16::from(mod_super) | extra).into();
            let m_shift: ModMask = (u16::from(mod_super_shift) | extra).into();
            conn.grab_key(false, root, m_super, kc, GrabMode::ASYNC, GrabMode::ASYNC)?;
            conn.grab_key(false, root, m_shift, kc, GrabMode::ASYNC, GrabMode::ASYNC)?;
        }
        desktop_keycodes.push((i - 1, kc));
    }

    conn.flush()?;

    let mut current_desktop: usize = 0;
    let mut desktops: [Vec<Window>; 9] = Default::default();
    let mut window_to_desktop: HashMap<Window, usize> = HashMap::new();
    let mut window_classes: HashMap<Window, String> = HashMap::new();
    let mut active_window: Window = 0;
    let mut fullscreen_window: Option<Window> = None;
    let mut drag: Option<DragState> = None;
    let mut super_pressed = false;
    let mut super_combo_fired = false;
    let mut last_10hz_check = Instant::now();

    write_current_desktop(0);
    update_desktop_file(0, &desktops);
    update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);

    loop {
        let screen_w = screen.width_in_pixels as u32;
        let screen_h = screen.height_in_pixels as u32;

        while let Ok(Some(event)) = conn.poll_for_event() {
            match event {
                Event::MapRequest(ev) => {
                    let is_override = if let Ok(cookie) = conn.get_window_attributes(ev.window) {
                        cookie.reply().map(|a| a.override_redirect).unwrap_or(false)
                    } else {
                        false
                    };

                    if is_override {
                        let _ = conn.map_window(ev.window);
                        continue;
                    }

                    if !window_to_desktop.contains_key(&ev.window) {
                        window_to_desktop.insert(ev.window, current_desktop);
                        desktops[current_desktop].push(ev.window);
                        let cls = query_wm_class(&conn, ev.window);
                        window_classes.insert(ev.window, cls);
                    }

                    let _ = conn.grab_button(
                        false,
                        ev.window,
                        EventMask::BUTTON_PRESS,
                        GrabMode::SYNC,
                        GrabMode::ASYNC,
                        0u32,
                        0u32,
                        ButtonIndex::M1,
                        ModMask::ANY,
                    );

                    let aux = ChangeWindowAttributesAux::default()
                        .border_pixel(cfg.border_color_active)
                        .event_mask(EventMask::ENTER_WINDOW | EventMask::FOCUS_CHANGE);
                    let _ = conn.change_window_attributes(ev.window, &aux);

                    let _ = conn.map_window(ev.window);
                    let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, ev.window, x11rb::CURRENT_TIME);
                    active_window = ev.window;

                    if fullscreen_window.is_none() {
                        retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                    }
                    update_desktop_file(current_desktop, &desktops);
                    update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
                    let _ = conn.flush();
                }

                Event::UnmapNotify(_) => {}

                Event::DestroyNotify(ev) => {
                    if fullscreen_window == Some(ev.window) {
                        fullscreen_window = None;
                    }
                    if let Some(desk) = window_to_desktop.remove(&ev.window) {
                        window_classes.remove(&ev.window);
                        desktops[desk].retain(|&w| w != ev.window);
                        if desk == current_desktop {
                            if active_window == ev.window {
                                active_window = desktops[current_desktop].last().copied().unwrap_or(0);
                            }
                            if fullscreen_window.is_none() {
                                retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                            }
                            update_desktop_file(current_desktop, &desktops);
                            update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
                            let _ = conn.flush();
                        }
                    }
                }

                Event::ConfigureRequest(ev) => {
                    if fullscreen_window == Some(ev.window) {
                        // Prevent client from shrinking out of fullscreen
                        let aux = ConfigureWindowAux::default()
                            .x(0)
                            .y(0)
                            .width(screen_w)
                            .height(screen_h)
                            .border_width(0);
                        let _ = conn.configure_window(ev.window, &aux);
                    } else if window_to_desktop.contains_key(&ev.window) && drag.is_none() && fullscreen_window.is_none() {
                        retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                    } else {
                        let aux = ConfigureWindowAux::from_configure_request(&ev);
                        let _ = conn.configure_window(ev.window, &aux);
                    }
                    let _ = conn.flush();
                }

                Event::ButtonPress(ev) => {
                    let is_super_held = ev.state.contains(KeyButMask::MOD4);
                    let clicked = if ev.child != 0 && ev.child != root { ev.child } else { ev.event };
                    let top_win = find_toplevel_window(&conn, root, clicked, &window_to_desktop);

                    if let Some(win) = top_win {
                        active_window = win;
                        let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, win, x11rb::CURRENT_TIME);
                        let _ = conn.configure_window(win, &ConfigureWindowAux::default().stack_mode(StackMode::ABOVE));

                        for &other in &desktops[current_desktop] {
                            let color = if other == win { cfg.border_color_active } else { cfg.border_color_inactive };
                            let _ = conn.change_window_attributes(other, &ChangeWindowAttributesAux::default().border_pixel(color));
                        }

                        if is_super_held {
                            if let Ok(geom_cookie) = conn.get_geometry(win) {
                                if let Ok(geom) = geom_cookie.reply() {
                                    drag = Some(DragState {
                                        window: win,
                                        start_mouse: (ev.root_x, ev.root_y),
                                        start_geom: (geom.x, geom.y, geom.width, geom.height),
                                        is_resize: ev.detail == 3,
                                    });
                                }
                            }
                        } else {
                            let _ = conn.allow_events(Allow::REPLAY_POINTER, ev.time);
                        }

                        let _ = conn.flush();
                        update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
                    } else {
                        let _ = conn.allow_events(Allow::REPLAY_POINTER, ev.time);
                    }
                }

                Event::MotionNotify(ev) => {
                    if let Some(ref d) = drag {
                        let dx = ev.root_x - d.start_mouse.0;
                        let dy = ev.root_y - d.start_mouse.1;
                        if d.is_resize {
                            let new_w = (d.start_geom.2 as i32 + dx as i32).max(180) as u32;
                            let new_h = (d.start_geom.3 as i32 + dy as i32).max(120) as u32;
                            let _ = conn.configure_window(d.window, &ConfigureWindowAux::default().width(new_w).height(new_h));
                        } else {
                            let new_x = d.start_geom.0 as i32 + dx as i32;
                            let new_y = d.start_geom.1 as i32 + dy as i32;
                            let _ = conn.configure_window(d.window, &ConfigureWindowAux::default().x(new_x).y(new_y));
                        }
                        let _ = conn.flush();
                    }
                }

                Event::ButtonRelease(_) => { drag = None; }

                Event::KeyPress(ev) => {
                    let is_super = Some(ev.detail) == kc_super_l || Some(ev.detail) == kc_super_r;
                    if is_super {
                        super_pressed = true;
                        super_combo_fired = false;
                    } else {
                        super_combo_fired = true;
                    }

                    let has_shift = ev.state.contains(KeyButMask::SHIFT);

                    for &(target_desk, kc) in &desktop_keycodes {
                        if ev.detail == kc {
                            fullscreen_window = None;
                            if has_shift {
                                if active_window != 0 && window_to_desktop.contains_key(&active_window) {
                                    let win = active_window;
                                    window_to_desktop.insert(win, target_desk);
                                    desktops[current_desktop].retain(|&w| w != win);
                                    desktops[target_desk].push(win);
                                    let _ = conn.unmap_window(win);

                                    if let Some(&next_win) = desktops[current_desktop].last() {
                                        active_window = next_win;
                                        let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, next_win, x11rb::CURRENT_TIME);
                                    } else {
                                        active_window = 0;
                                        let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, root, x11rb::CURRENT_TIME);
                                    }

                                    retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                                    update_desktop_file(current_desktop, &desktops);
                                    update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
                                }
                            } else {
                                switch_to_desktop(
                                    &conn,
                                    target_desk,
                                    &mut current_desktop,
                                    &desktops,
                                    &window_classes,
                                    &mut active_window,
                                    screen_w,
                                    screen_h,
                                    &cfg,
                                    root,
                                );
                            }
                            break;
                        }
                    }

                    // Win + F Monocle / Fullscreen Toggle
                    if ev.detail == kc_f && !has_shift && !is_super {
                        // Resolve target to the top-level window
                        let mut target_win = active_window;
                        if target_win == 0 || !window_to_desktop.contains_key(&target_win) {
                            if let Ok(focus) = conn.get_input_focus() {
                                if let Ok(reply) = focus.reply() {
                                    target_win = find_toplevel_window(&conn, root, reply.focus, &window_to_desktop).unwrap_or(0);
                                }
                            }
                        }
                        if target_win == 0 {
                            target_win = desktops[current_desktop].last().copied().unwrap_or(0);
                        }

                        if fullscreen_window.is_some() {
                            // Toggle OFF -> snap back to 50% split tile
                            fullscreen_window = None;
                            retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                            let _ = conn.flush();
                        } else if target_win != 0 {
                            // Toggle ON -> expand over 100% of screen
                            fullscreen_window = Some(target_win);
                            active_window = target_win;
                            let aux = ConfigureWindowAux::default()
                                .x(0)
                                .y(0)
                                .width(screen_w)
                                .height(screen_h)
                                .border_width(0)
                                .stack_mode(StackMode::ABOVE);
                            let _ = conn.configure_window(target_win, &aux);
                            let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, target_win, x11rb::CURRENT_TIME);
                            let _ = conn.flush();
                        }
                    }
                    else if ev.detail == kc_q && !has_shift && !is_super {
                        let _ = Command::new(&cfg.terminal).spawn();
                    } 
                    else if ev.detail == kc_q && has_shift {
                        let mut target_win: Option<Window> = None;
                        if let Ok(focus) = conn.get_input_focus() {
                            if let Ok(reply) = focus.reply() {
                                if reply.focus != root && reply.focus != 0 {
                                    target_win = find_toplevel_window(&conn, root, reply.focus, &window_to_desktop);
                                }
                            }
                        }

                        if target_win.is_none() {
                            target_win = desktops[current_desktop].last().copied();
                        }

                        if let Some(win) = target_win {
                            if fullscreen_window == Some(win) {
                                fullscreen_window = None;
                            }
                            let _ = conn.unmap_window(win);
                            let _ = conn.kill_client(win);
                            window_to_desktop.remove(&win);
                            window_classes.remove(&win);
                            desktops[current_desktop].retain(|&w| w != win);

                            if let Some(&next_win) = desktops[current_desktop].last() {
                                active_window = next_win;
                                let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, next_win, x11rb::CURRENT_TIME);
                            } else {
                                active_window = 0;
                                let _ = conn.set_input_focus(InputFocus::POINTER_ROOT, root, x11rb::CURRENT_TIME);
                            }

                            retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                            update_desktop_file(current_desktop, &desktops);
                            update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
                            let _ = conn.flush();
                        }
                    } else if ev.detail == kc_return && !has_shift && !is_super {
                        let _ = Command::new("bash").arg("-c").arg(&cfg.launcher).spawn();
                    } else if ev.detail == kc_w && !has_shift && !is_super {
                        let _ = Command::new("bash").arg("-c").arg(&cfg.control_cmd).spawn();
                    } else if ev.detail == kc_e && has_shift {
                        break;
                    }
                }

                Event::KeyRelease(ev) => {
                    let is_super = Some(ev.detail) == kc_super_l || Some(ev.detail) == kc_super_r;
                    if is_super {
                        if super_pressed && !super_combo_fired {
                            let parts: Vec<&str> = cfg.launcher.split_whitespace().collect();
                            if !parts.is_empty() {
                                let _ = Command::new(parts[0]).args(&parts[1..]).spawn();
                            }
                        }
                        super_pressed = false;
                    }
                }
                _ => {}
            }
        }

        if let Some(mut path) = dirs::config_dir() {
            path.push("glasswm/switch_desktop");
            if path.exists() {
                if let Ok(content) = fs::read_to_string(&path) {
                    let _ = fs::remove_file(&path);
                    if let Ok(num) = content.trim().parse::<usize>() {
                        if num >= 1 && num <= 9 {
                            fullscreen_window = None;
                            switch_to_desktop(
                                &conn,
                                num - 1,
                                &mut current_desktop,
                                &desktops,
                                &window_classes,
                                &mut active_window,
                                screen_w,
                                screen_h,
                                &cfg,
                                root,
                            );
                        }
                    }
                }
            }
        }

        if last_10hz_check.elapsed() >= Duration::from_millis(100) {
            last_10hz_check = Instant::now();

            let mut current_desk_changed = false;

            for d in 0..9 {
                let mut alive = Vec::new();
                let mut desk_changed = false;

                for &win in &desktops[d] {
                    let is_alive = if let Ok(cookie) = conn.get_geometry(win) {
                        cookie.reply().is_ok()
                    } else {
                        false
                    };

                    if is_alive {
                        alive.push(win);
                    } else {
                        if fullscreen_window == Some(win) {
                            fullscreen_window = None;
                        }
                        window_to_desktop.remove(&win);
                        window_classes.remove(&win);
                        desk_changed = true;
                    }
                }

                if desk_changed || alive.len() != desktops[d].len() {
                    desktops[d] = alive;
                    if d == current_desktop {
                        current_desk_changed = true;
                    }
                }
            }

            if current_desk_changed && fullscreen_window.is_none() {
                active_window = desktops[current_desktop].last().copied().unwrap_or(0);
                retile_desktop(&conn, screen_w, screen_h, &cfg, &desktops[current_desktop], &window_classes);
                let _ = conn.flush();
            }

            update_desktop_file(current_desktop, &desktops);
            update_taskbar_file(&desktops[current_desktop], &window_classes, active_window);
        }

        thread::sleep(Duration::from_millis(10));
    }
    Ok(())
}
