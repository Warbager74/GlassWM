import math
import os

WP_DIR = os.path.expanduser("~/.config/glasswm/wallpapers")
os.makedirs(WP_DIR, exist_ok=True)
WIDTH, HEIGHT = 1920, 1080

def create_mesh(filename):
    with open(filename, 'wb') as f:
        f.write(f"P6\n{WIDTH} {HEIGHT}\n255\n".encode())
        for y in range(HEIGHT):
            row = bytearray()
            ny = y / HEIGHT
            wave = 0.08 * math.sin(ny * 4.0)
            for x in range(WIDTH):
                nx = x / WIDTH + wave
                
                # Fluid gradient matching Lumen (Purple #2c1a4d, Deep Blue #0d1b2a, Teal #143642)
                r = int(25 + 65 * math.sin(nx * 2.8) + 40 * ny)
                g = int(18 + 42 * math.cos(ny * 3.2) + 20 * nx)
                b = int(55 + 75 * math.sin((nx + ny) * 2.5) + 30)

                row.extend((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))
            f.write(row)

create_mesh(f"{WP_DIR}/lumen_liquid.ppm")
