"""Compose the fly-in-a-box video: body cameras, what the eyes see, the brain lighting up, and the
descending-neuron meters. Reads the run directory written by flybox.py."""
import argparse, json, os
import numpy as np
import imageio
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument("--run", default="out/run1")
p.add_argument("--out", default="out/fly_in_a_box.mp4")
p.add_argument("--fps", type=int, default=30)
args = p.parse_args()

log = json.load(open(f"{args.run}/log.json"))
spk = np.load(f"{args.run}/spikes.npz")
soma = np.load(f"{args.run}/soma_xy.npy")
sclass = np.load(f"{args.run}/super_class.npy", allow_pickle=True)
n_frames = len(log["t"])

W, H = 1920, 1080
try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 26)
    FONT_S = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    FONT_B = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
except OSError:
    FONT = FONT_S = FONT_B = ImageFont.load_default()

# ---- brain panel geometry: soma positions (um) -> pixels, viewed from the front (x right, y down = ventral)
BX, BY, BW, BH = 1300, 60, 580, 420
x = soma[:, 0]; y = soma[:, 1]
ok = np.isfinite(x) & np.isfinite(y)
xmin, xmax = np.nanpercentile(x[ok], [0.5, 99.5]); ymin, ymax = np.nanpercentile(y[ok], [0.5, 99.5])
sx = (BW - 20) / (xmax - xmin); sy = (BH - 20) / (ymax - ymin); s = min(sx, sy)
px = (BX + 10 + (x - xmin) * s).astype(int); py = (BY + 10 + (y - ymin) * s).astype(int)
px = np.clip(px, BX, BX + BW - 1); py = np.clip(py, BY, BY + BH - 1)
CLASS_COLORS = {
    "optic": (70, 110, 200), "visual_projection": (90, 190, 230), "central": (230, 200, 90), "sensory": (120, 200, 120),
    "descending": (255, 90, 60), "ascending": (200, 120, 220), "motor": (255, 60, 160), "sensory_ascending": (120, 200, 120),
    "visual_centrifugal": (90, 190, 230), "endocrine": (200, 200, 200),
}
colors = np.array([CLASS_COLORS.get(str(c), (160, 160, 160)) for c in sclass], dtype=np.uint8)
# faint background of every neuron
bg = np.zeros((H, W, 3), np.uint8); bg[:] = (12, 12, 16)
brain_bg = np.zeros((BH, BW), np.float32)
np.add.at(brain_bg, (py[ok] - BY, px[ok] - BX), 1.0)
brain_bg = np.clip(brain_bg / 3.0, 0, 1)[..., None] * np.array([40, 40, 52], np.float32)
bg[BY:BY + BH, BX:BX + BW] = brain_bg.astype(np.uint8)

GLOW = np.zeros((H, W, 3), np.float32)
def paint_spikes(img, ids, decay):
    global GLOW
    GLOW *= decay
    if len(ids):
        GLOW[py[ids], px[ids]] = np.maximum(GLOW[py[ids], px[ids]], colors[ids].astype(np.float32))
        # make spiking neurons 2 px wide
        GLOW[np.minimum(py[ids] + 1, H - 1), px[ids]] = np.maximum(GLOW[np.minimum(py[ids] + 1, H - 1), px[ids]], colors[ids] * 0.7)
        GLOW[py[ids], np.minimum(px[ids] + 1, W - 1)] = np.maximum(GLOW[py[ids], np.minimum(px[ids] + 1, W - 1)], colors[ids] * 0.7)
    region = GLOW[BY:BY + BH, BX:BX + BW]
    img[BY:BY + BH, BX:BX + BW] = np.clip(img[BY:BY + BH, BX:BX + BW] + region, 0, 255).astype(np.uint8)

def eye_image(lum, size):
    # hex readouts -> tiny image: use the ommatidia centroids map
    cent = np.load("out/omm_centroids.npy")
    img = np.zeros((size, size), np.float32) + 0.06
    rr = (cent[:, 0] / 512 * (size - 1)).astype(int); cc = (cent[:, 1] / 450 * (size - 1)).astype(int)
    for r_, c_, v in zip(rr, cc, lum):
        img[max(r_ - 3, 0):r_ + 4, max(c_ - 3, 0):c_ + 4] = v
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)

METERS = [("DNa02", "turn (ipsilateral)"), ("DNa01", "turn, slow"), ("DNp09", "walk forward"), ("MDN", "walk backward"), ("DNp01", "giant fibre: escape"), ("MN9", "proboscis: feed")]

writer = imageio.get_writer(args.out, fps=args.fps, codec="libx264", quality=8, macro_block_size=1)
for i in range(n_frames):
    img = bg.copy()
    if os.path.exists(f"{args.run}/frames/follow_{i:05d}.png"):
        last_follow = np.asarray(Image.open(f"{args.run}/frames/follow_{i:05d}.png").resize((1120, 840)))
        last_over = np.asarray(Image.open(f"{args.run}/frames/overhead_{i:05d}.png").resize((400, 300)))
    follow, over = last_follow, last_over
    img[60:900, 40:1160] = follow
    img[920:920 + 150, 40:40 + 200] = np.asarray(Image.fromarray(over).resize((200, 150)))
    lum = np.load(f"{args.run}/frames/eyes_{i:05d}.npy").astype(np.float32)
    for e in range(2):
        ey = eye_image(lum[e], 150)
        img[920:1070, 270 + e * 165:420 + e * 165] = np.stack([ey] * 3, -1)
    ids = spk[f"f{i}"]
    paint_spikes(img, ids, 0.55)

    pil = Image.fromarray(img); d = ImageDraw.Draw(pil)
    t = log["t"][i]
    d.text((40, 12), "A FLY IN A BOX", font=FONT_B, fill=(240, 235, 225))
    d.text((350, 20), f"t = {t:5.2f} s   real FlyWire brain: 138,639 neurons, 15.1M synapses   NeuroMechFly body", font=FONT_S, fill=(170, 170, 180))
    d.text((40, 896), "overhead", font=FONT_S, fill=(150, 150, 160)); d.text((270, 896), "left eye", font=FONT_S, fill=(150, 150, 160)); d.text((435, 896), "right eye", font=FONT_S, fill=(150, 150, 160))
    d.text((BX, BY - 36), f"brain activity  ({len(ids):,} neurons fired this frame)", font=FONT, fill=(220, 220, 230))
    # legend
    lx = BX; ly = BY + BH + 8
    for k, (name, col) in enumerate([("optic lobe", CLASS_COLORS["optic"]), ("visual projection", CLASS_COLORS["visual_projection"]), ("central brain", CLASS_COLORS["central"]), ("sensory", CLASS_COLORS["sensory"]), ("descending", CLASS_COLORS["descending"]), ("motor", CLASS_COLORS["motor"])]):
        xx = lx + (k % 3) * 190; yy = ly + (k // 3) * 24
        d.rectangle([xx, yy + 6, xx + 12, yy + 18], fill=col); d.text((xx + 18, yy), name, font=FONT_S, fill=(190, 190, 200))
    # meters
    my = BY + BH + 70
    d.text((BX, my), "descending / motor neurons  (Hz, left | right)", font=FONT, fill=(220, 220, 230)); my += 36
    for name, desc in METERS:
        l, r = log["rates"][name][i]
        d.text((BX, my), f"{name:6s}", font=FONT_S, fill=(255, 120, 90)); d.text((BX + 90, my), desc, font=FONT_S, fill=(170, 170, 180))
        for j, v in enumerate((l, r)):
            x0 = BX + 320 + j * 135; d.rectangle([x0, my + 4, x0 + 80, my + 20], outline=(70, 70, 80))
            d.rectangle([x0, my + 4, x0 + int(min(v, 150) / 150 * 80), my + 20], fill=(255, 140, 90) if v > 0 else (40, 40, 50))
            d.text((x0 + 86, my - 2), f"{v:3.0f}", font=FONT_S, fill=(200, 200, 210))
        my += 30
    # inputs + body
    odour, tasting, touching, lum_mean = log["inputs"][i]
    dl, dr = log["drive"][i]
    my += 10
    d.text((BX, my), f"senses in:  odour {odour:4.2f}   taste {'YES' if tasting else 'no '}   head touch {'YES' if touching else 'no '}", font=FONT_S, fill=(140, 210, 140)); my += 28
    d.text((BX, my), f"legs out:   left drive {dl:+.2f}   right drive {dr:+.2f}", font=FONT_S, fill=(210, 190, 120)); my += 28
    ev = log["events"][i]
    if ev["feeding"]: d.text((BX, my), "FEEDING", font=FONT_B, fill=(255, 120, 200))
    if ev["startle"]: d.text((BX + 200, my), "STARTLE", font=FONT_B, fill=(255, 90, 60))
    writer.append_data(np.asarray(pil))
    if i % 100 == 0: print(f"  frame {i}/{n_frames}", flush=True)
writer.close(); print("saved", args.out)
