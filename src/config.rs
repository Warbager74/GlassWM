use serde::Deserialize;
use std::fs;

#[allow(dead_code)]
#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub border_width: u32,
    pub border_color_active: u32,
    pub border_color_inactive: u32,
    pub top_bar_height: u32,
    pub bottom_dock_height: u32,
    pub window_gap: u32,
    pub terminal: String,
    pub launcher: String,
    pub control_cmd: String,
    pub autostart_script: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            border_width: 1,
            border_color_active: 0x565f89,
            border_color_inactive: 0x1a1b26,
            top_bar_height: 30,
            bottom_dock_height: 44,
            window_gap: 10,
            terminal: "kitty".to_string(),
            launcher: "rofi -show drun -theme ~/.config/glasswm/rofi/start_menu.rasi".to_string(),
            control_cmd: "bash ~/.config/glasswm/scripts/control_center.sh".to_string(),
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
