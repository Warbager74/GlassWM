import struct
import math
import os

WP_DIR = os.path.expanduser("~/.config/glasswm/wallpapers")
os.makedirs(WP_DIR, exist_ok=True)
WIDTH, HEIGHT = 1920, 1080

def create_liquid_wallpaper(filename, color_stops):
    with open(filename, 'wb') as f:
        f.write(f"P6\n{WIDTH} {HEIGHT}\n255\n".encode())
        for y in range(HEIGHT):
            row = bytearray()
            v = y / HEIGHT
            wave = 0.05 * math.sin(y * 0.015)
            for x in range(WIDTH):
                u = x / WIDTH + wave
                t = (u * 0.6 + v * 0.4) % 1.0
                if t < 0.33:
                    f_factor = t / 0.33
                    c1, c2 = color_stops[0], color_stops[1]
                elif t < 0.66:
                    f_factor = (t - 0.33) / 0.33
                    c1, c2 = color_stops[1], color_stops[2]
                else:
                    f_factor = (t - 0.66) / 0.34
                    c1, c2 = color_stops[2], color_stops[3]
                r = int(c1[0] + (c2[0] - c1[0]) * f_factor)
                g = int(c1[1] + (c2[1] - c1[1]) * f_factor)
                b = int(c1[2] + (c2[2] - c1[2]) * f_factor)
                row.extend((r, g, b))
            f.write(row)

create_liquid_wallpaper(f"{WP_DIR}/1_deep_ocean.ppm", [(10, 17, 40), (0, 31, 84), (3, 64, 120), (18, 130, 162)])
create_liquid_wallpaper(f"{WP_DIR}/2_violet_sunset.ppm", [(36, 0, 70), (90, 24, 154), (157, 78, 221), (255, 117, 143)])
create_liquid_wallpaper(f"{WP_DIR}/3_emerald_aurora.ppm", [(8, 28, 21), (27, 67, 50), (45, 106, 79), (82, 183, 136)])
create_liquid_wallpaper(f"{WP_DIR}/4_midnight_obsidian.ppm", [(13, 13, 17), (26, 26, 36), (46, 48, 62), (80, 84, 100)])
