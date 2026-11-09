import numpy as np, math, random, base64
from PIL import Image, ImageDraw, ImageFilter, ImageChops

rng = np.random.default_rng(7)
random.seed(7)

def value_noise(w, h, cell, seed):
    r = np.random.default_rng(seed)
    gw, gh = max(2, w // cell + 2), max(2, h // cell + 2)
    grid = (r.random((gh, gw)) * 255).astype(np.uint8)
    im = Image.fromarray(grid, 'L').resize((w, h), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255.0

def fbm(w, h, base, octaves, seed, gain=0.5):
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0.0; cell = base
    for i in range(octaves):
        out += amp * value_noise(w, h, max(2, int(cell)), seed + i * 101)
        tot += amp; amp *= gain; cell /= 2
    return out / tot

def ridged(w, h, base, octaves, seed, sharp=2.2):
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0.0; cell = base
    for i in range(octaves):
        n = value_noise(w, h, max(2, int(cell)), seed + i * 37)
        n = 1.0 - np.abs(2 * n - 1)          # ridges
        n = n ** sharp
        out += amp * n; tot += amp; amp *= 0.55; cell /= 2
    return out / tot

def radial(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (x - w / 2) / (w / 2); ny = (y - h / 2) / (h / 2)
    return np.sqrt(nx * nx + ny * ny)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def warp(field, dx, dy, amount):
    # cheap domain warp: shift lookup by noise, bilinear-free (nearest) is fine for smoke
    h, w = field.shape
    yy, xx = np.mgrid[0:h, 0:w]
    sx = np.clip((xx + (dx - 0.5) * amount).astype(int), 0, w - 1)
    sy = np.clip((yy + (dy - 0.5) * amount).astype(int), 0, h - 1)
    return field[sy, sx]

def save_la(lum, alpha, name):
    L = (np.clip(lum, 0, 1) * 255).astype(np.uint8); A = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    im = Image.merge('LA', (Image.fromarray(L, 'L'), Image.fromarray(A, 'L')))
    im.save(name, optimize=True)
    return im

# ---------------- smoke: deep body of the vignette, clear ellipse in the middle
W, H = 512, 288
r = radial(W, H)
n1 = fbm(W, H, 110, 5, 11); n2 = fbm(W, H, 70, 4, 23)
n1 = warp(n1, n2, fbm(W, H, 60, 3, 29), 60)
mask = smoothstep(0.70, 1.22, r)
corner = smoothstep(1.0, 1.42, r)
body = np.clip((n1 - 0.25) / 0.75, 0, 1) ** 1.4
alpha = mask * (0.18 + 0.82 * body) + corner * 0.22 * body
alpha = np.clip(alpha, 0, 1) * 0.72
lum = 0.35 + 0.65 * (0.5 * n1 + 0.5 * n2)
save_la(lum, alpha, 'aura_smoke.png')
# shade: a dark vignette under everything so the corners brood
shade_a = smoothstep(0.78, 1.42, r) ** 1.3 * 0.62
save_la(np.zeros_like(r), shade_a, 'aura_shade.png')

# ---------------- wisps: bright energy filaments, two seeds for crossfade
W, H = 768, 432
r = radial(W, H)
mask = smoothstep(0.62, 1.05, r) * (1 - 0.25 * smoothstep(1.2, 1.42, r))
for name, seed in (('aura_wispsA.png', 101), ('aura_wispsB.png', 202)):
    rd = ridged(W, H, 90, 5, seed, sharp=2.6)
    rd = warp(rd, fbm(W, H, 120, 3, seed + 5), fbm(W, H, 120, 3, seed + 9), 90)
    rd = np.clip((rd - 0.22) / 0.78, 0, 1) ** 1.5
    alpha = mask * rd * 1.0
    lum = 0.55 + 0.45 * rd                          # cores brightest
    save_la(lum, alpha, name)

# ---------------- runes: cirth-like glyphs along an ellipse, with glow
W, H = 1024, 576
cx, cy = W / 2, H / 2
layer = Image.new('L', (W, H), 0)
d = ImageDraw.Draw(layer)
def glyph(size):
    g = Image.new('L', (size, size), 0); gd = ImageDraw.Draw(g)
    s = size; x0 = s * 0.5; top, bot = s * 0.08, s * 0.92; lw = max(2, s // 9)
    gd.line([(x0, top), (x0, bot)], fill=255, width=lw)
    if random.random() < 0.3:  # second stem
        x1 = x0 + random.choice((-1, 1)) * s * 0.32
        gd.line([(x1, top), (x1, bot)], fill=255, width=lw)
    for _ in range(random.randint(1, 3)):
        y = random.uniform(top + s * 0.1, bot - s * 0.1)
        side = random.choice((-1, 1)); length = random.uniform(0.25, 0.42) * s
        ang = random.choice((-50, -35, 0, 35, 50)); a = math.radians(ang)
        x2 = x0 + side * length * math.cos(a); y2 = y + length * math.sin(a)
        gd.line([(x0, y), (x2, y2)], fill=255, width=lw)
        if random.random() < 0.35:
            gd.line([(x2, y2), (x2, y2 + random.choice((-1, 1)) * s * 0.2)], fill=255, width=lw)
    if random.random() < 0.3:  # dot
        gd.ellipse([x0 + s * 0.2, top + s * 0.1, x0 + s * 0.2 + lw, top + s * 0.1 + lw], fill=255)
    return g
def ellipse_pt(t, rx, ry):
    return cx + rx * math.cos(t), cy + ry * math.sin(t)
rx, ry = W * 0.455, H * 0.465
arcs = [(-168, -104), (-76, -12), (12, 76), (104, 168)]   # degrees, screen coords (y down)
size = 22
for a0, a1 in arcs:
    # faint band along the arc
    pts = [ellipse_pt(math.radians(a), rx, ry) for a in np.linspace(a0 - 4, a1 + 4, 60)]
    d.line(pts, fill=70, width=2)
    pts2 = [ellipse_pt(math.radians(a), rx * 0.985, ry * 0.985) for a in np.linspace(a0 - 2, a1 + 2, 60)]
    d.line(pts2, fill=40, width=1)
    # perimeter length approx -> glyph spacing
    steps = int(abs(a1 - a0) / 3.6)
    for i in range(steps):
        a = math.radians(a0 + (a1 - a0) * (i + 0.5) / steps)
        x, y = ellipse_pt(a, rx, ry)
        # tangent angle for rotation
        tx, ty = -rx * math.sin(a), ry * math.cos(a)
        rot = -math.degrees(math.atan2(ty, tx))
        g = glyph(size).rotate(rot, resample=Image.BICUBIC, expand=True)
        layer.paste(255, (int(x - g.width / 2), int(y - g.height / 2)), g)
glow = layer.filter(ImageFilter.GaussianBlur(7))
glow2 = layer.filter(ImageFilter.GaussianBlur(18))
alpha = np.clip(0.8 * np.asarray(layer) / 255.0 + 1.1 * np.asarray(glow) / 255.0 + 0.8 * np.asarray(glow2) / 255.0, 0, 1)
lum = np.clip(0.6 + 0.4 * np.asarray(layer) / 255.0, 0, 1)
save_la(lum, alpha * 0.8, 'aura_runes.png')

# ---------------- eye glow: soft radial, slightly flame-edged
W = H = 224
r = radial(W, H)
n = fbm(W, H, 40, 3, 303)
a = np.clip(1 - r / (0.80 + 0.20 * n), 0, 1) ** 1.25
lum = 0.75 + 0.25 * np.clip(1 - r, 0, 1)
save_la(lum, a, 'eye_glow.png')

import os
for f in ('aura_shade.png', 'aura_smoke.png', 'aura_wispsA.png', 'aura_wispsB.png', 'aura_runes.png', 'eye_glow.png'):
    print(f, os.path.getsize(f))

# ---------------- composite previews (what Roblox will show after tinting)
def tint(la, rgb):
    L, A = la.split(); arr = np.asarray(L).astype(np.float32) / 255
    out = np.zeros((la.height, la.width, 4), np.uint8)
    for i in range(3): out[..., i] = (arr * rgb[i]).astype(np.uint8)
    out[..., 3] = np.asarray(A)
    return Image.fromarray(out, 'RGBA')
def composite(theme, out):
    SW, SH = 1280, 720
    bg = Image.new('RGBA', (SW, SH), (14, 14, 18, 255))
    bd = ImageDraw.Draw(bg); bd.rectangle([0, SH * 0.45, SW, SH], fill=(28, 27, 30, 255)); bd.rectangle([0, 0, SW, SH * 0.45], fill=(10, 10, 14, 255))
    for i in range(12): bd.line([(SW/2 + (i-6)*160, SH), (SW/2 + (i-6)*30, SH*0.45)], fill=(50,50,56,255), width=2)
    smoke, wisp, rune, eyec = theme
    lay = lambda name, c, sw, sh, alpha=1.0: bg.alpha_composite(Image.eval(tint(Image.open(name), c).resize((sw, sh), Image.BICUBIC), lambda v: v) if alpha == 1 else tint(Image.open(name), c).resize((sw, sh), Image.BICUBIC), (0, 0))
    def put(name, c, mul):
        im = tint(Image.open(name), c).resize((SW, SH), Image.BICUBIC)
        if mul != 1:
            r_, g_, b_, a_ = im.split(); a_ = a_.point(lambda v: int(v * mul)); im = Image.merge('RGBA', (r_, g_, b_, a_))
        bg.alpha_composite(im)
    put('aura_shade.png', (0, 0, 0), 1.0)
    put('aura_smoke.png', smoke, 1.0)
    put('aura_wispsA.png', wisp, 0.8)
    put('aura_wispsB.png', wisp, 0.35)
    put('aura_runes.png', rune, 1.0)
    g = tint(Image.open('eye_glow.png'), wisp).resize((190, 190))
    bg.alpha_composite(g, (SW//2 - 95, 76 - 95))
    eye = Image.open(eyec).resize((60, 60), Image.LANCZOS)
    bg.alpha_composite(eye, (SW//2 - 30, 46))
    bg.convert('RGB').save(out)
composite(((0, 150, 40), (130, 255, 120), (200, 255, 210), 'eye_green.png'), 'aura_preview_green.png')
composite(((200, 18, 8), (255, 110, 30), (255, 190, 90), 'eye_red.png'), 'aura_preview_red.png')
print('previews written')
