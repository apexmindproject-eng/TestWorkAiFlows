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
HIGHLIGHT = {}   # neuron index -> colour, drawn as 5x5 blocks
if os.path.exists(f"{args.run}/highlight.json"):
    for name, (idx_list, col) in json.load(open(f"{args.run}/highlight.json")).items():
        for j in idx_list: HIGHLIGHT[int(j)] = tuple(col)
hl_idx = np.array(sorted(HIGHLIGHT), dtype=int); hl_col = np.array([HIGHLIGHT[j] for j in hl_idx], dtype=np.float32) if len(hl_idx) else np.zeros((0, 3), np.float32)
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
    if len(hl_idx):
        fired = np.isin(hl_idx, ids)
        for j, c, f in zip(hl_idx, hl_col, fired):
            y0, x0 = py[j], px[j]
            GLOW[max(y0-2,0):y0+3, max(x0-2,0):x0+3] = np.maximum(GLOW[max(y0-2,0):y0+3, max(x0-2,0):x0+3], c if f else c * 0.25)
    region = GLOW[BY:BY + BH, BX:BX + BW]
    img[BY:BY + BH, BX:BX + BW] = np.clip(img[BY:BY + BH, BX:BX + BW] + region, 0, 255).astype(np.uint8)

CENT = np.load("out/omm_centroids.npy")
def eye_image(px, size):
    # per-ommatidium colour (or brightness) -> tiny image using the ommatidia centroid map
    img = np.zeros((size, size, 3), np.float32) + 0.06
    rr = (CENT[:, 0] / 512 * (size - 1)).astype(int); cc = (CENT[:, 1] / 450 * (size - 1)).astype(int)
    for r_, c_, v in zip(rr, cc, px):
        img[max(r_ - 3, 0):r_ + 4, max(c_ - 3, 0):c_ + 4] = v
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)

METERS = [("DNa02", "turn (ipsilateral)"), ("DNp01", "giant fibre: escape"), ("DNg12", "grooming command"), ("MN9", "proboscis: feed"), ("PAMrw", "reward dopamine")]

writer = imageio.get_writer(args.out, fps=args.fps, codec="libx264", quality=8, macro_block_size=1)
for i in range(n_frames):
    img = bg.copy()
    mode_now = log["inner"][i][0] if "inner" in log else ""
    px, py = log["pose"][i][0], log["pose"][i][1]
    inside = lambda off: abs(px + off[0]) < 28.5 and abs(py + off[1]) < 28.5          # is a camera at this offset inside the box?
    fol = "follow" if (inside((-3, -12)) or not inside((3, 12))) else "follow_b"
    clo = "close" if (inside((2.4, -4.2)) or not inside((-2.4, 4.2))) else "close_b"
    use_close = (mode_now == "feed" or mode_now.startswith("groom") or mode_now in ("mount", "climb", "turnaround", "descend")) and os.path.exists(f"{args.run}/frames/{clo}_{i:05d}.png")
    if os.path.exists(f"{args.run}/frames/{fol}_{i:05d}.png"):
        last_follow = np.asarray(Image.open(f"{args.run}/frames/{clo if use_close else fol}_{i:05d}.png").resize((1120, 840)))
        last_over = np.asarray(Image.open(f"{args.run}/frames/overhead_{i:05d}.png").resize((400, 300)))
    follow, over = last_follow, last_over
    img[60:900, 40:1160] = follow
    img[920:920 + 150, 40:40 + 200] = np.asarray(Image.fromarray(over).resize((200, 150)))
    eyes = np.load(f"{args.run}/frames/eyes_{i:05d}.npy").astype(np.float32)
    if eyes.ndim == 2:
        eyes = np.repeat(eyes[..., None], 3, axis=-1)
    for e in range(2):
        img[920:1070, 270 + e * 165:420 + e * 165] = eye_image(eyes[e], 150)
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
    for k, (name, col) in enumerate([("optic lobe", CLASS_COLORS["optic"]), ("visual projection", CLASS_COLORS["visual_projection"]), ("central brain", CLASS_COLORS["central"]), ("sensory", CLASS_COLORS["sensory"]), ("descending", CLASS_COLORS["descending"]), ("reward (PAM)", (255, 80, 200))]):
        xx = lx + (k % 3) * 190; yy = ly + (k // 3) * 24
        d.rectangle([xx, yy + 6, xx + 12, yy + 18], fill=col); d.text((xx + 18, yy), name, font=FONT_S, fill=(190, 190, 200))
    # meters
    my = BY + BH + 70
    d.text((BX, my), "descending / motor neurons  (Hz, left | right)", font=FONT, fill=(220, 220, 230)); my += 36
    for name, desc in METERS:
        if name not in log["rates"]:
            continue
        l, r = log["rates"][name][i]
        d.text((BX, my), f"{name:6s}", font=FONT_S, fill=(255, 120, 90)); d.text((BX + 90, my), desc, font=FONT_S, fill=(170, 170, 180))
        for j, v in enumerate((l, r)):
            x0 = BX + 320 + j * 135; d.rectangle([x0, my + 4, x0 + 80, my + 20], outline=(70, 70, 80))
            d.rectangle([x0, my + 4, x0 + int(min(v, 150) / 150 * 80), my + 20], fill=(255, 140, 90) if v > 0 else (40, 40, 50))
            d.text((x0 + 86, my - 2), f"{v:3.0f}", font=FONT_S, fill=(200, 200, 210))
        my += 30
    # inputs + body
    inp = log["inputs"][i]; odour, tasting, touching, lum_mean = inp[:4]
    objL, objR, loomL, loomR = (inp[4:8] if len(inp) >= 8 else (0, 0, 0, 0))
    dl, dr = log["drive"][i]
    my += 10
    d.text((BX, my), f"senses in:  odour {odour:4.2f}   taste {'YES' if tasting else 'no '}   head touch {'YES' if touching else 'no '}", font=FONT_S, fill=(140, 210, 140)); my += 26
    d.text((BX, my), f"eyes:  dark object L {objL:4.2f} R {objR:4.2f}   looming L {loomL:4.2f} R {loomR:4.2f}", font=FONT_S, fill=(140, 190, 230)); my += 28
    d.text((BX, my), f"legs out:   left drive {dl:+.2f}   right drive {dr:+.2f}", font=FONT_S, fill=(210, 190, 120)); my += 28
    if "inner" in log:
        mode, hunger, brain_turn, odour_turn, spont = log["inner"][i][:5]
        my += 6
        d.text((BX, my), "inner state (behaviour layer, not the wiring):", font=FONT_S, fill=(200, 170, 120)); my += 26
        d.text((BX, my), f"hunger", font=FONT_S, fill=(200, 200, 210))
        d.rectangle([BX + 80, my + 4, BX + 230, my + 20], outline=(70, 70, 80)); d.rectangle([BX + 80, my + 4, BX + 80 + int(hunger * 150), my + 20], fill=(230, 160, 70))
        d.text((BX + 240, my), {"walk": "walking", "pause": "pausing", "wall": "following the wall", "feed": "FEEDING", "escape": "ESCAPE", "groom:front rub": "grooming: front legs", "groom:head groom": "grooming: head", "groom:hind rub": "grooming: hind legs", "approach": "walking up to the wall", "mount": "CLIMBING: rearing up onto the wall", "climb": "CLIMBING the wall", "turnaround": "turning round on the wall", "descend": "walking down the wall"}.get(mode, mode), font=FONT_B if mode in ("feed", "escape", "mount", "climb") else FONT, fill=(255, 120, 200) if mode == "feed" else (255, 90, 60) if mode == "escape" else (120, 220, 160) if mode in ("mount", "climb") else (220, 220, 230)); my += 30
        d.text((BX, my), f"steering:  brain {brain_turn:+.2f}   smell {odour_turn:+.2f}   spontaneous {spont:+.2f}", font=FONT_S, fill=(200, 200, 210)); my += 28
        if len(log["inner"][i]) >= 8:
            rew, mem = log["inner"][i][6], log["inner"][i][7]
            d.text((BX, my), "reward", font=FONT_S, fill=(200, 200, 210)); d.rectangle([BX + 80, my + 4, BX + 230, my + 20], outline=(70, 70, 80)); d.rectangle([BX + 80, my + 4, BX + 80 + int(rew * 150), my + 20], fill=(255, 100, 180))
            d.text((BX + 250, my), "food memory", font=FONT_S, fill=(200, 200, 210)); d.rectangle([BX + 370, my + 4, BX + 520, my + 20], outline=(70, 70, 80)); d.rectangle([BX + 370, my + 4, BX + 370 + int(mem * 150), my + 20], fill=(120, 200, 255))
    else:
        ev = log["events"][i]
        if ev["feeding"]: d.text((BX, my), "FEEDING", font=FONT_B, fill=(255, 120, 200))
        if ev["startle"]: d.text((BX + 200, my), "STARTLE", font=FONT_B, fill=(255, 90, 60))
    writer.append_data(np.asarray(pil))
    if i % 100 == 0: print(f"  frame {i}/{n_frames}", flush=True)
writer.close(); print("saved", args.out)
