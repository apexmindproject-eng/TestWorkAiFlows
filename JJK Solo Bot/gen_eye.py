import numpy as np, math, random, os
from PIL import Image, ImageDraw, ImageFilter
random.seed(11)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def periodic_value_noise(w, h, cells_x, cells_y, seed, periodic_x=True):
    """value noise on a (w x h) field; x wraps so polar fields have no seam."""
    r = np.random.default_rng(seed)
    g = r.random((cells_y + 1, cells_x + (0 if periodic_x else 1)))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    fx = xs / w * cells_x; fy = ys / h * cells_y
    x0 = np.floor(fx).astype(int); y0 = np.floor(fy).astype(int)
    tx = fx - x0; ty = fy - y0
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
    y0 = np.clip(y0, 0, cells_y - 1); y1 = y0 + 1
    if periodic_x:
        x0 = x0 % cells_x; x1 = (x0 + 1) % cells_x
    else:
        x0 = np.clip(x0, 0, cells_x - 1); x1 = x0 + 1
    a = g[y0, x0]; b = g[y0, x1]; c = g[y1, x0]; d = g[y1, x1]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

def polar_fbm(w, h, base_cells, octaves, seed, ridged=False, gain=0.5):
    out = np.zeros((h, w), np.float32); amp = 1; tot = 0; cx, cy = base_cells
    for i in range(octaves):
        n = periodic_value_noise(w, h, int(cx), int(cy), seed + 13 * i)
        if ridged: n = (1 - np.abs(2 * n - 1)) ** 2.4
        out += amp * n; tot += amp; amp *= gain; cx *= 2; cy *= 2
    return out / tot

def to_cartesian(polar, size, r_max=1.0):
    """polar image: x = angle (0..2pi), y = radius (0..r_max). Returns size x size field."""
    ph, pw = polar.shape
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    nx = (xs - size / 2) / (size / 2); ny = (ys - size / 2) / (size / 2)
    rr = np.sqrt(nx * nx + ny * ny); th = np.arctan2(ny, nx)
    xi = ((th + math.pi) / (2 * math.pi) * pw).astype(int) % pw
    yi = np.clip((rr / r_max * ph).astype(int), 0, ph - 1)
    return polar[yi, xi], rr, th

def save_la(lum, alpha, name):
    L = (np.clip(lum, 0, 1) * 255).astype(np.uint8); A = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    Image.merge('LA', (Image.fromarray(L, 'L'), Image.fromarray(A, 'L'))).save(name, optimize=True)

S = 320
# ---------------- eye fire: filaments radiating from the eye, two seeds
for name, seed in (('eye_fireA.png', 501), ('eye_fireB.png', 777)):
    big = polar_fbm(1024, 256, (12, 3), 3, seed, ridged=True, gain=0.45)       # a dozen bold tongues
    fine = polar_fbm(1024, 256, (40, 6), 3, seed + 50, ridged=True, gain=0.5)   # detail inside them
    pol = np.clip(0.7 * big + 0.45 * fine * big, 0, 1)
    # curl the tongues: shear angle by radius so they swirl
    rows = []
    for yi in range(pol.shape[0]):
        rows.append(np.roll(pol[yi], int(yi * 1.7)))
    pol = np.array(rows)
    fil, rr, th = to_cartesian(pol, S, 1.0)
    edge = 0.52 + 0.42 * to_cartesian(polar_fbm(512, 8, (7, 1), 2, seed + 3), S, 1.0)[0]
    mask = smoothstep(0.24, 0.36, rr) * (1 - smoothstep(edge - 0.22, edge, rr))
    fil = np.clip((fil - 0.12) / 0.88, 0, 1) ** 1.25
    alpha = np.clip(fil * mask * 1.25, 0, 1)
    # brightest nearest the eye, hot cores
    lum = 0.5 + 0.5 * (1 - smoothstep(0.28, 0.85, rr)) * (0.4 + 0.6 * fil)
    save_la(lum, alpha, name)

# ---------------- eye smoke: soft puffs around, larger and dim
pol = polar_fbm(1024, 256, (7, 2), 5, 909, ridged=False, gain=0.55)
rows = []
for yi in range(pol.shape[0]):
    rows.append(np.roll(pol[yi], int(yi * 0.8)))
pol = np.array(rows)
sm, rr, th = to_cartesian(pol, S, 1.0)
edge = 0.70 + 0.30 * to_cartesian(polar_fbm(512, 8, (6, 1), 2, 919), S, 1.0)[0]
mask = smoothstep(0.22, 0.42, rr) * (1 - smoothstep(edge - 0.28, edge, rr))
body = np.clip((sm - 0.28) / 0.72, 0, 1) ** 1.1
save_la(0.3 + 0.5 * body, np.clip(body * mask * 1.15, 0, 1), 'eye_smoke.png')

# ---------------- menu haze: black brushed smear, soft irregular edges
W, H = 512, 768
ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
nx = xs / W; ny = ys / H
box = smoothstep(0, 0.30, nx) * (1 - smoothstep(0.62, 1.0, nx)) * smoothstep(0, 0.12, ny) * (1 - smoothstep(0.88, 1.0, ny))
streak = periodic_value_noise(W, H, 3, 40, 42, periodic_x=False)       # horizontal brush streaks
grain = periodic_value_noise(W, H, 24, 36, 43, periodic_x=False)
a = box * (0.72 + 0.28 * streak) * (0.85 + 0.15 * grain)
a = np.clip(a * 0.9, 0, 1)
save_la(np.zeros_like(a), a, 'menu_haze.png')

# ---------------- runes: a dim base plus four twinkle groups that flare
W, H = 1024, 576
cx, cy = W / 2, H / 2
def glyph(size):
    g = Image.new('L', (size, size), 0); gd = ImageDraw.Draw(g)
    s = size; x0 = s * 0.5; top, bot = s * 0.08, s * 0.92; lw = max(2, s // 8)
    gd.line([(x0, top), (x0, bot)], fill=255, width=lw)
    if random.random() < 0.3:
        x1 = x0 + random.choice((-1, 1)) * s * 0.32
        gd.line([(x1, top), (x1, bot)], fill=255, width=lw)
    for _ in range(random.randint(1, 3)):
        y = random.uniform(top + s * 0.1, bot - s * 0.1)
        side = random.choice((-1, 1)); length = random.uniform(0.25, 0.42) * s
        a = math.radians(random.choice((-50, -35, 0, 35, 50)))
        x2 = x0 + side * length * math.cos(a); y2 = y + length * math.sin(a)
        gd.line([(x0, y), (x2, y2)], fill=255, width=lw)
        if random.random() < 0.35:
            gd.line([(x2, y2), (x2, y2 + random.choice((-1, 1)) * s * 0.2)], fill=255, width=lw)
    if random.random() < 0.3:
        gd.ellipse([x0 + s * 0.2, top + s * 0.1, x0 + s * 0.2 + lw, top + s * 0.1 + lw], fill=255)
    return g
def ellipse_pt(t, rx, ry): return cx + rx * math.cos(t), cy + ry * math.sin(t)
rx, ry = W * 0.455, H * 0.465
arcs = [(-168, -104), (-76, -12), (12, 76), (104, 168)]
size = 26
groups = [Image.new('L', (W, H), 0) for _ in range(4)]
band = Image.new('L', (W, H), 0); bd = ImageDraw.Draw(band)
k = 0
for a0, a1 in arcs:
    pts = [ellipse_pt(math.radians(a), rx, ry) for a in np.linspace(a0 - 4, a1 + 4, 60)]
    bd.line(pts, fill=90, width=2)
    steps = int(abs(a1 - a0) / 3.4)
    for i in range(steps):
        a = math.radians(a0 + (a1 - a0) * (i + 0.5) / steps)
        x, y = ellipse_pt(a, rx, ry)
        tx, ty = -rx * math.sin(a), ry * math.cos(a)
        rot = -math.degrees(math.atan2(ty, tx))
        g = glyph(size).rotate(rot, resample=Image.BICUBIC, expand=True)
        groups[k % 4].paste(255, (int(x - g.width / 2), int(y - g.height / 2)), g)
        k += 1
allg = Image.new('L', (W, H), 0)
for g in groups: allg.paste(255, (0, 0), g)
# base: every glyph, lit softly, with the band
glow = allg.filter(ImageFilter.GaussianBlur(6))
alpha = np.clip(0.55 * np.asarray(allg) / 255 + 0.7 * np.asarray(glow) / 255 + 0.5 * np.asarray(band) / 255, 0, 1)
lum = np.clip(0.45 + 0.55 * np.asarray(allg) / 255, 0, 1)
save_la(lum, alpha * 0.8, 'runes_base.png')
# twinkle groups: hot core and a wide flare
for i, g in enumerate(groups):
    g1 = g.filter(ImageFilter.GaussianBlur(5)); g2 = g.filter(ImageFilter.GaussianBlur(24))
    alpha = np.clip(np.asarray(g) / 255 + 1.3 * np.asarray(g1) / 255 + 1.4 * np.asarray(g2) / 255, 0, 1)
    lum = np.clip(0.75 + 0.25 * np.asarray(g) / 255, 0, 1)
    save_la(lum, alpha, f'runes_s{i+1}.png')

for f in ('eye_fireA.png', 'eye_fireB.png', 'eye_smoke.png', 'menu_haze.png', 'runes_base.png', 'runes_s1.png', 'runes_s2.png', 'runes_s3.png', 'runes_s4.png'):
    print(f, os.path.getsize(f))

# ---------------- preview composite of the eye cluster on dark
def tint(name, rgb, size=None):
    la = Image.open(name); L, A = la.split(); arr = np.asarray(L).astype(np.float32) / 255
    out = np.zeros((la.height, la.width, 4), np.uint8)
    for i in range(3): out[..., i] = (arr * rgb[i]).astype(np.uint8)
    out[..., 3] = np.asarray(A)
    im = Image.fromarray(out, 'RGBA')
    return im.resize(size, Image.BICUBIC) if size else im
def eye_preview(theme, eye, out):
    smoke, wisp, rune = theme
    bg = Image.new('RGBA', (420, 420), (12, 12, 16, 255))
    sz = 360; o = (420 - sz) // 2
    bg.alpha_composite(tint('eye_smoke.png', smoke, (sz, sz)), (o, o))
    fa = tint('eye_fireA.png', wisp, (sz, sz)); bg.alpha_composite(fa, (o, o))
    fb = tint('eye_fireB.png', wisp, (sz, sz)).rotate(40); r_, g_, b_, a_ = fb.split(); a_ = a_.point(lambda v: int(v * 0.5)); bg.alpha_composite(Image.merge('RGBA', (r_, g_, b_, a_)), (o, o))
    e = Image.open(eye).resize((110, 110), Image.LANCZOS); bg.alpha_composite(e, (155, 155))
    bg.convert('RGB').save(out)
eye_preview(((0, 170, 50), (140, 255, 130), (210, 255, 220)), 'eye_green.png', 'eyefx_preview_green.png')
eye_preview(((255, 46, 10), (255, 150, 40), (255, 210, 120)), 'eye_red.png', 'eyefx_preview_red.png')
# runes + haze preview strip
bg = Image.new('RGBA', (1024, 576), (14, 14, 18, 255))
bg.alpha_composite(tint('runes_base.png', (210, 255, 220)))
bg.alpha_composite(tint('runes_s1.png', (230, 255, 240)))
hz = tint('menu_haze.png', (0, 0, 0), (420, 480)); bg.alpha_composite(hz, (20, 50))
bg.convert('RGB').save('runes_preview.png')
print('previews ok')
