import zlib
import struct
import math
import os

def write_png(filename, width, height, rgba_data):
    # Construct PNG file
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    magic = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    
    raw_rows = []
    for y in range(height):
        row = bytearray(b'\x00') # Filter type 0
        start = y * width * 4
        row.extend(rgba_data[start:start + width * 4])
        raw_rows.append(bytes(row))
        
    compressed_data = zlib.compress(b''.join(raw_rows), 9)
    
    png = magic + chunk(b'IHDR', ihdr) + chunk(b'IDAT', compressed_data) + chunk(b'IEND', b'')
    with open(filename, 'wb') as f:
        f.write(png)

def is_inside_wallet(nx, ny):
    # nx, ny are in [0, 24] coordinate space
    # 1. Check outer body bounds [3, 21] x [3, 21]
    in_body_rect = (3 <= nx <= 21) and (3 <= ny <= 21)
    
    if in_body_rect:
        # Check 4 outer corners (radius 2)
        if nx < 5 and ny < 5:
            if (nx - 5)**2 + (ny - 5)**2 > 4:
                in_body_rect = False
        elif nx < 5 and ny > 19:
            if (nx - 5)**2 + (ny - 19)**2 > 4:
                in_body_rect = False
        elif nx > 19 and ny < 5:
            if (nx - 19)**2 + (ny - 5)**2 > 4:
                in_body_rect = False
        elif nx > 19 and ny > 19:
            if (nx - 19)**2 + (ny - 19)**2 > 4:
                in_body_rect = False
                
        # Check inner cutout on the right side
        if in_body_rect:
            if nx >= 12 and 6 <= ny <= 18:
                in_body_rect = False
            elif 10 <= nx < 12 and 8 <= ny <= 16:
                in_body_rect = False
            elif 10 <= nx < 12 and 6 <= ny < 8:
                # Top inner corner radius 2 at (12, 8)
                if (nx - 12)**2 + (ny - 8)**2 < 4:
                    in_body_rect = False
            elif 10 <= nx < 12 and 16 < ny <= 18:
                # Bottom inner corner radius 2 at (12, 16)
                if (nx - 12)**2 + (ny - 16)**2 < 4:
                    in_body_rect = False
    
    # 2. Check flap: [12, 22] x [8, 16]
    in_flap = (12 <= nx <= 22) and (8 <= ny <= 16)
    
    # 3. Check clasp hole: circle at (16, 12) radius 1.5
    in_hole = ((nx - 16)**2 + (ny - 12)**2) <= 1.5**2
    
    if in_flap and not in_hole:
        return True
    if in_body_rect:
        return True
    return False

def render_icon(width, height, icon_size, bg_color, fg_color, out_path):
    # bg_color: (R, G, B, A)
    # fg_color: (R, G, B, A)
    data = bytearray(width * height * 4)
    
    center_x = width / 2.0
    center_y = height / 2.0
    scale = icon_size / 24.0 # icon is 24x24 units
    
    # Supersampling 4x4 for anti-aliasing
    subsamples = [-0.375, -0.125, 0.125, 0.375]
    
    for y in range(height):
        for x in range(width):
            coverage = 0
            for sy in subsamples:
                py = y + sy
                ny = (py - center_y) / scale + 12.0
                for sx in subsamples:
                    px = x + sx
                    nx = (px - center_x) / scale + 12.0
                    if 0 <= nx <= 24 and 0 <= ny <= 24:
                        if is_inside_wallet(nx, ny):
                            coverage += 1
            
            cov_frac = coverage / 16.0 # 0.0 to 1.0
            
            # Blend fg over bg
            idx = (y * width + x) * 4
            
            # Background
            bg_r, bg_g, bg_b, bg_a = bg_color
            fg_r, fg_g, fg_b, fg_a = fg_color
            
            final_a = bg_a * (1.0 - cov_frac) + fg_a * cov_frac
            if final_a > 0:
                final_r = int((bg_r * bg_a * (1.0 - cov_frac) + fg_r * fg_a * cov_frac) / final_a)
                final_g = int((bg_g * bg_a * (1.0 - cov_frac) + fg_g * fg_a * cov_frac) / final_a)
                final_b = int((bg_b * bg_a * (1.0 - cov_frac) + fg_b * fg_a * cov_frac) / final_a)
                final_a_byte = int(final_a)
            else:
                final_r = final_g = final_b = final_a_byte = 0
                
            data[idx] = final_r
            data[idx+1] = final_g
            data[idx+2] = final_b
            data[idx+3] = final_a_byte
            
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    write_png(out_path, width, height, data)
    print(f"Generated {out_path}")

# Primary container color in app: #0D3B2E -> (13, 59, 46, 255)
GREEN = (13, 59, 46, 255)
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

# Full icon 1024x1024 with icon_size 580 (approx 57% of canvas)
render_icon(1024, 1024, 580, GREEN, WHITE, "assets/icon/app_icon.png")

# Foreground adaptive icon 1024x1024 with icon_size 460 (safe within center 66% zone)
render_icon(1024, 1024, 460, TRANSPARENT, WHITE, "assets/icon/app_icon_foreground.png")
