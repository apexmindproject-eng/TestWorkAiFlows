import numpy as np, math, random, os
from PIL import Image, ImageDraw, ImageFilter
random.seed(23)

def save_la(L, A, name):
    Image.merge('LA', (L, A)).save(name, optimize=True)

# ------------------------------------------------------------ hp frame
# Drawn at 2x and reduced. Final 600x72, shown at 150x18. The hole the fill
# shows through is x 60..540, y 24..48.
SS = 2
W, H = 600 * SS, 72 * SS
lum = Image.new('L', (W, H), 0); alp = Image.new('L', (W, H), 0)
dl, da = ImageDraw.Draw(lum), ImageDraw.Draw(alp)
def P(pts): return [(x * SS, y * SS) for x, y in pts]
def shape(pts, l):
    dl.polygon(P(pts), fill=int(l * 255)); da.polygon(P(pts), fill=255)
def mirror(pts): return [(600 - x, y) for x, y in pts]
# rails
shape([(52, 17), (548, 17), (548, 24), (52, 24)], 0.95)
shape([(52, 48), (548, 48), (548, 55), (52, 55)], 0.62)
# thin outer hairlines
shape([(70, 12), (530, 12), (530, 14), (70, 14)], 0.5)
shape([(70, 58), (530, 58), (530, 60), (70, 60)], 0.35)
for flip in (False, True):
    m = mirror if flip else (lambda p: p)
    # arrowhead cap
    shape(m([(60, 17), (60, 55), (46, 55), (6, 36), (46, 17)]), 0.78)
    shape(m([(60, 17), (46, 17), (6, 36), (30, 36), (48, 26), (60, 26)]), 0.98)   # lit upper facet
    # barbs
    shape(m([(58, 17), (78, 3), (72, 17)]), 0.9)
    shape(m([(58, 55), (78, 69), (72, 55)]), 0.55)
    shape(m([(40, 20), (30, 6), (34, 24)]), 0.8)
    shape(m([(40, 52), (30, 66), (34, 48)]), 0.5)
    # stud
    shape(m([(40, 36), (32, 30), (24, 36), (32, 42)]), 0.18)
    shape(m([(37, 36), (32, 32), (27, 36), (32, 40)]), 1.0)
    # third ticks
    x = 220 if not flip else 220
    shape(m([(218, 24), (222, 24), (222, 30), (218, 30)]), 0.8)
    shape(m([(218, 42), (222, 42), (222, 48), (218, 48)]), 0.55)
# centre ornament
shape([(300, 5), (311, 19), (300, 29), (289, 19)], 0.25)
shape([(300, 9), (307, 19), (300, 25), (293, 19)], 1.0)
shape([(300, 67), (308, 56), (300, 47), (292, 56)], 0.5)
lum = lum.resize((600, 72), Image.LANCZOS); alp = alp.resize((600, 72), Image.LANCZOS)
# a soft black shadow under the metal so it reads on bright ground
sh = alp.filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(v * 0.75))
A = np.maximum(np.asarray(alp), np.asarray(sh)); Lm = (np.asarray(lum).astype(np.float32) * (np.asarray(alp) / 255.0)).astype(np.uint8)
# keep the hole clear of shadow
A[24:48, 60:540] = np.asarray(alp)[24:48, 60:540]
save_la(Image.fromarray(Lm, 'L'), Image.fromarray(A, 'L'), 'hp_frame.png')

# ------------------------------------------------------------ particle sprites
def noise(w, h, cell, seed):
    r = np.random.default_rng(seed)
    g = (r.random((h // cell + 2, w // cell + 2)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(g, 'L').resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
S = 128
ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
nx = (xs - S / 2) / (S * 0.36); ny = (ys - S * 0.56) / (S * 0.44)
# teardrop: narrower toward the top
nx = nx * (1 + 0.55 * np.clip(-ny, 0, 1))
r = np.sqrt(nx * nx + ny * ny)
n = 0.6 * noise(S, S, 22, 5) + 0.4 * noise(S, S, 9, 6)
rid = (1 - np.abs(2 * noise(S, S, 14, 9) - 1)) ** 1.6
a = np.clip(1 - r, 0, 1) ** 1.3 * (0.45 + 0.55 * n) * (0.6 + 0.4 * rid)
a = np.clip(a * 1.5, 0, 1)
save_la(Image.fromarray(np.full((S, S), 255, np.uint8), 'L'), Image.fromarray((a * 255).astype(np.uint8), 'L'), 'fx_flame.png')
S = 48
ys, xs = np.mgrid[0:S, 0:S].astype(np.float32)
dx = (xs - S / 2) / (S / 2); dy = (ys - S / 2) / (S / 2)
r = np.sqrt(dx * dx + dy * dy)
a = np.exp(-(r * 3.2) ** 2) + 0.35 * np.exp(-(np.abs(dx) * 9) ** 2) * np.clip(1 - np.abs(dy), 0, 1) ** 2 + 0.35 * np.exp(-(np.abs(dy) * 9) ** 2) * np.clip(1 - np.abs(dx), 0, 1) ** 2
save_la(Image.fromarray(np.full((S, S), 255, np.uint8), 'L'), Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), 'L'), 'fx_ember.png')

# ------------------------------------------------------------ ground sigil
S = 512; c = S / 2
def glyph(size):
    g = Image.new('L', (size, size), 0); gd = ImageDraw.Draw(g)
    s = size; x0 = s * 0.5; top, bot = s * 0.08, s * 0.92; lw = max(2, s // 8)
    gd.line([(x0, top), (x0, bot)], fill=255, width=lw)
    if random.random() < 0.3:
        x1 = x0 + random.choice((-1, 1)) * s * 0.32; gd.line([(x1, top), (x1, bot)], fill=255, width=lw)
    for _ in range(random.randint(1, 3)):
        y = random.uniform(top + s * 0.1, bot - s * 0.1); side = random.choice((-1, 1)); length = random.uniform(0.25, 0.42) * s
        ang = math.radians(random.choice((-50, -35, 0, 35, 50)))
        x2 = x0 + side * length * math.cos(ang); y2 = y + length * math.sin(ang)
        gd.line([(x0, y), (x2, y2)], fill=255, width=lw)
    return g
def glowed(layer, k1=4, k2=14):
    g1 = layer.filter(ImageFilter.GaussianBlur(k1)); g2 = layer.filter(ImageFilter.GaussianBlur(k2))
    A = np.clip(np.asarray(layer) / 255 + 0.9 * np.asarray(g1) / 255 + 0.7 * np.asarray(g2) / 255, 0, 1)
    L = np.clip(0.6 + 0.4 * np.asarray(layer) / 255, 0, 1)
    return Image.fromarray((L * 255).astype(np.uint8), 'L'), Image.fromarray((A * 255).astype(np.uint8), 'L')
# outer ring of runes between two circles
ring = Image.new('L', (S, S), 0); d = ImageDraw.Draw(ring)
for rad, w in ((244, 3), (206, 2), (198, 1)):
    d.ellipse([c - rad, c - rad, c + rad, c + rad], outline=255, width=w)
N = 30
for i in range(N):
    a = 2 * math.pi * i / N
    x, y = c + 225 * math.cos(a), c + 225 * math.sin(a)
    g = glyph(30).rotate(-math.degrees(a) - 90, resample=Image.BICUBIC, expand=True)
    ring.paste(255, (int(x - g.width / 2), int(y - g.height / 2)), g)
for i in range(60):
    a = 2 * math.pi * i / 60
    d.line([(c + 198 * math.cos(a), c + 198 * math.sin(a)), (c + (190 if i % 5 else 180) * math.cos(a), c + (190 if i % 5 else 180) * math.sin(a))], fill=200, width=2)
L, A = glowed(ring); save_la(L, A, 'fx_circle.png')
# inner sigil: an eight-pointed star, a circle, and the slit of the eye
sig = Image.new('L', (S, S), 0); d = ImageDraw.Draw(sig)
d.ellipse([c - 172, c - 172, c + 172, c + 172], outline=255, width=2)
for rot in (0, 45):
    pts = [(c + 172 * math.cos(math.radians(rot + 90 * k)), c + 172 * math.sin(math.radians(rot + 90 * k))) for k in range(4)]
    d.polygon(pts, outline=255); d.line(pts + [pts[0]], fill=255, width=3)
d.ellipse([c - 92, c - 92, c + 92, c + 92], outline=255, width=3)
d.ellipse([c - 84, c - 84, c + 84, c + 84], outline=180, width=1)
# the eye: an almond and an upright slit
lens = [(c - 78, c)] + [(c + 78 * math.cos(t), c - 34 * math.sin(t)) for t in np.linspace(math.pi, 0, 30)] + [(c + 78 * math.cos(t), c + 34 * math.sin(t)) for t in np.linspace(0, math.pi, 30)]
d.line(lens + [lens[0]], fill=255, width=3)
slit = [(c, c - 30)] + [(c + 9 * math.sin(t), c - 30 * math.cos(t)) for t in np.linspace(0, math.pi, 20)] + [(c - 9 * math.sin(t), c + 30 * math.cos(t)) for t in np.linspace(0, math.pi, 20)]
d.polygon(slit, fill=255)
for k in range(8):
    a = math.radians(22.5 + 45 * k)
    d.line([(c + 100 * math.cos(a), c + 100 * math.sin(a)), (c + 160 * math.cos(a), c + 160 * math.sin(a))], fill=160, width=2)
L, A = glowed(sig); save_la(L, A, 'fx_sigil.png')

for f in ('hp_frame.png', 'fx_flame.png', 'fx_ember.png', 'fx_circle.png', 'fx_sigil.png'):
    print(f, os.path.getsize(f))

# ------------------------------------------------------------ previews
def tint(name, rgb, size=None):
    la = Image.open(name); L, A = la.split(); arr = np.asarray(L).astype(np.float32) / 255
    out = np.zeros((la.height, la.width, 4), np.uint8)
    for i in range(3): out[..., i] = (arr * rgb[i]).astype(np.uint8)
    out[..., 3] = np.asarray(A)
    im = Image.fromarray(out, 'RGBA'); return im.resize(size, Image.LANCZOS) if size else im
def bar(bg, x, y, pct, ghost, fill_a, fill_b, frame_rgb, scale=2):
    w, h = 150 * scale, 18 * scale
    d = ImageDraw.Draw(bg, 'RGBA')
    hx, hy, hw, hh = x + 15 * scale, y + 6 * scale, 120 * scale, 6 * scale
    d.rectangle([hx, hy, hx + hw, hy + hh], fill=(6, 4, 4, 190))
    d.rectangle([hx, hy, hx + int(hw * ghost), hy + hh], fill=(255, 240, 220, 230))
    for i in range(int(hw * pct)):
        t = i / max(1, hw - 1); col = tuple(int(fill_a[k] + (fill_b[k] - fill_a[k]) * t) for k in range(3))
        d.line([(hx + i, hy), (hx + i, hy + hh)], fill=col + (255,))
    bg.alpha_composite(tint('hp_frame.png', frame_rgb, (w, h)), (x, y))
bg = Image.new('RGBA', (760, 360), (60, 62, 66, 255))
ImageDraw.Draw(bg).rectangle([0, 180, 760, 360], fill=(22, 22, 26, 255))
bar(bg, 40, 40, 0.62, 0.78, (120, 8, 8), (236, 52, 28), (190, 180, 165))
bar(bg, 400, 40, 1.0, 1.0, (120, 8, 8), (236, 52, 28), (255, 214, 96))
bar(bg, 40, 220, 0.3, 0.3, (20, 150, 60), (200, 255, 220), (190, 180, 165))
bar(bg, 400, 220, 0.85, 0.85, (200, 60, 10), (255, 214, 96), (190, 180, 165))
bg.convert('RGB').save('hp_preview.png')
g = Image.new('RGBA', (560, 560), (16, 16, 20, 255))
g.alpha_composite(tint('fx_circle.png', (255, 200, 110)), (24, 24)); g.alpha_composite(tint('fx_sigil.png', (255, 120, 30)), (24, 24))
g.alpha_composite(tint('fx_flame.png', (255, 150, 40), (128, 128)), (10, 10)); g.alpha_composite(tint('fx_ember.png', (255, 230, 150), (48, 48)), (150, 20))
g.convert('RGB').save('fx_preview.png')
print('previews ok')
