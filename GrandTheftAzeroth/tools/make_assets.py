#!/usr/bin/env python3
"""Generate all Grand Theft Azeroth textures and sounds from scratch (no third-party art)."""
import math
import random
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "media" / "fonts"
TEX = ROOT / "media" / "textures"
SND = ROOT / "media" / "sounds"
random.seed(1337)
np.random.seed(1337)

BANGERS = str(FONTS / "Bangers-Regular.ttf")
ANTON = str(FONTS / "Anton-Regular.ttf")
MARKER = str(FONTS / "PermanentMarker-Regular.ttf")

RED = (214, 32, 32, 255)
GOLD = (255, 196, 40, 255)
GREEN = (60, 200, 90, 255)
BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
PINK = (255, 70, 170, 255)
CYAN = (40, 220, 255, 255)


def font(path, size):
    return ImageFont.truetype(path, size)


def save(img, name):
    TEX.mkdir(parents=True, exist_ok=True)
    img.save(TEX / f"{name}.png")


def shear(img, amount=-0.18):
    w, h = img.size
    return img.transform((w, h), Image.AFFINE, (1, amount, -amount * h / 2, 0, 1, 0), Image.BICUBIC)


def grunge(img, strength=0.35):
    alpha = np.array(img.getchannel("A"), dtype=np.float32)
    noise = np.random.rand(*alpha.shape)
    blobs = Image.fromarray((np.random.rand(alpha.shape[0] // 8, alpha.shape[1] // 8) * 255).astype(np.uint8))
    blobs = np.array(blobs.resize(img.size, Image.BICUBIC), dtype=np.float32) / 255
    mask = np.where((noise < strength * 0.15) | (blobs < strength * 0.35), 0.25, 1.0)
    img.putalpha(Image.fromarray((alpha * mask).astype(np.uint8)))
    return img


def centered_text(size, text, fnt, fill, stroke=8, stroke_fill=BLACK, slant=-0.18, shadow=True, rough=0.3):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), text, font=fnt, stroke_width=stroke)
    x = (size[0] - (box[2] - box[0])) / 2 - box[0]
    y = (size[1] - (box[3] - box[1])) / 2 - box[1]
    if shadow:
        sh = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((x + 8, y + 10), text, font=fnt, fill=(0, 0, 0, 170), stroke_width=stroke, stroke_fill=(0, 0, 0, 170))
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(6)))
        d = ImageDraw.Draw(img)
    d.text((x, y), text, font=fnt, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)
    if slant:
        img = shear(img, slant)
    if rough:
        img = grunge(img, rough)
    return img


def star_polygon(cx, cy, r_out, r_in, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def burst(size, spikes, fill, outline=BLACK, jag=0.25, width=8):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    pts = []
    for i in range(spikes * 2):
        r = c * 0.95 if i % 2 == 0 else c * (0.62 + random.uniform(-jag, jag) * 0.4)
        a = 2 * math.pi * i / (spikes * 2)
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    ImageDraw.Draw(img).polygon(pts, fill=fill, outline=outline, width=width)
    return img


def overlay_text(img, text, fnt, fill, stroke=6, slant=-0.12, rough=0.0):
    return Image.alpha_composite(img, centered_text(img.size, text, fnt, fill, stroke=stroke, slant=slant, shadow=False, rough=rough))


def textures():
    # Death screen variants (big slanted red title).
    for name, text, col in [
        ("death_flattened", "FLATTENED", RED),
        ("death_deleted", "DELETED", RED),
        ("death_yeeted", "YEETED", RED),
        ("death_respawn_pending", "RESPAWN PENDING", RED),
        ("death_nicked", "NICKED", (60, 120, 255, 255)),
    ]:
        save(centered_text((1024, 256), text, font(ANTON if len(text) > 9 else BANGERS, 150 if len(text) > 9 else 190), col), name)

    save(centered_text((1024, 256), "MISSION PASSED!", font(BANGERS, 150), GOLD), "mission_passed")
    save(centered_text((1024, 256), "MISSION FAILED", font(BANGERS, 150), RED), "mission_failed")
    save(centered_text((1024, 256), "LEVEL UP, KINGPIN", font(BANGERS, 130), GREEN), "level_up")
    save(centered_text((1024, 256), "SHOPPING SPREE", font(BANGERS, 140), PINK), "shopping_spree")
    save(centered_text((1024, 256), "GRAND THEFT AZEROTH", font(ANTON, 120), WHITE, stroke=10, rough=0.15), "logo_wordmark")

    # Wanted stars.
    for name, fill, outline in [("star_full", WHITE, BLACK), ("star_empty", (0, 0, 0, 90), (255, 255, 255, 200)), ("star_hot", GOLD, RED)]:
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(img).polygon(star_polygon(32, 34, 30, 12), fill=fill, outline=outline, width=4)
        save(img, name)

    # Cartoon burst stickers.
    for name, text, fill, tcol in [
        ("burst_kapow", "KAPOW!", GOLD, RED),
        ("burst_crit", "CRIT!", RED, WHITE),
        ("burst_oof", "OOF", CYAN, BLACK),
        ("burst_loot", "LOOT!", GREEN, WHITE),
        ("burst_bonk", "BONK", PINK, WHITE),
        ("burst_splash", "SPLOOSH", CYAN, WHITE),
    ]:
        save(overlay_text(burst(256, 14, fill), text, font(BANGERS, 70 if len(text) < 6 else 52), tcol), name)

    # Cheat activated stamp.
    img = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((20, 40, 492, 216), 18, outline=RED, width=14)
    img = Image.alpha_composite(img, centered_text((512, 256), "CHEAT ACTIVATED", font(ANTON, 66), RED, stroke=0, slant=0, shadow=False, rough=0))
    save(grunge(img.rotate(-8, Image.BICUBIC), 0.6), "stamp_cheat")

    # Phone with notification card.
    img = Image.new("RGBA", (256, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8, 8, 248, 504), 36, fill=(25, 25, 30, 255), outline=(120, 120, 130, 255), width=6)
    d.rounded_rectangle((22, 40, 234, 460), 14, fill=(40, 170, 255, 255))
    for y in range(40, 460, 6):
        d.line((22, y, 234, y), fill=(30, 140 + (y % 60), 230, 255))
    d.rounded_rectangle((96, 18, 160, 28), 5, fill=(60, 60, 70, 255))
    d.ellipse((108, 470, 148, 500), outline=(120, 120, 130, 255), width=4)
    save(img, "phone")

    # Subtitle / notification panel.
    img = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 4, 508, 124), 18, fill=(0, 0, 0, 200), outline=WHITE, width=3)
    save(img, "panel_dark")

    # Ride card background (bottom-right vehicle name).
    img = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(40, 10), (508, 10), (472, 118), (4, 118)], fill=(0, 0, 0, 180))
    d.line([(40, 10), (508, 10)], fill=GOLD, width=6)
    save(img, "card_ride")

    # District card brush stroke.
    img = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(70):
        y = 128 + random.randint(-60, 60)
        x0, x1 = random.randint(0, 120), random.randint(880, 1024)
        d.line((x0, y, x1, y + random.randint(-12, 12)), fill=(0, 0, 0, random.randint(20, 60)), width=random.randint(6, 22))
    save(img.filter(ImageFilter.GaussianBlur(2)), "card_district")

    # Radio wheel.
    img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cols = [RED, GOLD, GREEN, CYAN, PINK, (160, 90, 255, 255), (255, 130, 30, 255), WHITE]
    for i, col in enumerate(cols):
        d.pieslice((16, 16, 496, 496), i * 45 - 112.5, i * 45 - 67.5, fill=col[:3] + (200,), outline=BLACK, width=6)
    d.ellipse((160, 160, 352, 352), fill=(20, 20, 20, 255), outline=WHITE, width=6)
    img = overlay_text(img, "FM", font(BANGERS, 90), WHITE, stroke=4, slant=0)
    save(img, "radio_wheel")

    # Siren lights.
    for name, col in [("siren_red", (255, 30, 30)), ("siren_blue", (30, 80, 255))]:
        img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        g = Image.new("L", (128, 128), 0)
        ImageDraw.Draw(g).ellipse((14, 14, 114, 114), fill=255)
        g = g.filter(ImageFilter.GaussianBlur(14))
        img.paste(col + (255,), (0, 0), g)
        save(img, name)

    # Full-screen vignettes (stretched in-game).
    for name, col in [("vignette_grey", (40, 40, 40)), ("vignette_red", (160, 0, 0)), ("vignette_gold", (200, 150, 0))]:
        a = np.zeros((256, 256), np.float32)
        yy, xx = np.mgrid[0:256, 0:256]
        r = np.sqrt((xx - 128) ** 2 + (yy - 128) ** 2) / 181
        a = np.clip((r - 0.35) * 1.6, 0, 1) * 230
        img = Image.new("RGBA", (256, 256), col + (0,))
        img.putalpha(Image.fromarray(a.astype(np.uint8)))
        save(img, name)

    # Cash icon.
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(4):
        d.rounded_rectangle((14, 70 - i * 14, 114, 104 - i * 14), 6, fill=(40, 150 + i * 20, 60, 255), outline=BLACK, width=4)
    img = overlay_text(img, "$", font(BANGERS, 90), GOLD, stroke=6, slant=0)
    save(img, "cash")

    # Respect badge.
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon(star_polygon(64, 66, 60, 44, points=12), fill=GOLD, outline=BLACK, width=5)
    img = overlay_text(img, "R+", font(BANGERS, 56), RED, stroke=4, slant=0)
    save(img, "respect")

    # Wanted poster frame with a hole for the player portrait.
    img = Image.new("RGBA", (256, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((6, 6, 250, 506), fill=(222, 196, 140, 255), outline=(110, 80, 40, 255), width=6)
    d.rectangle((40, 120, 216, 296), fill=(0, 0, 0, 0), outline=(70, 50, 30, 255), width=6)
    pt = centered_text((256, 110), "WANTED", font(ANTON, 76), (90, 30, 20, 255), stroke=0, slant=0, shadow=False, rough=0)
    img.alpha_composite(pt, (0, 8))
    for i, t in enumerate(["FOR CRIMES AGAINST", "MURLOC-KIND", "REWARD: 3 COPPER"]):
        tl = centered_text((256, 50), t, font(ANTON, 26), (90, 30, 20, 255), stroke=0, slant=0, shadow=False, rough=0)
        img.alpha_composite(tl, (0, 320 + i * 50))
    save(grunge(img, 0.25), "poster_wanted")

    # Confetti strip (tiled / animated in-game).
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(90):
        x, y = random.randint(0, 250), random.randint(0, 250)
        d.rectangle((x, y, x + random.randint(4, 10), y + random.randint(8, 16)), fill=random.choice(cols))
    save(img, "confetti")

    # Bird splat.
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((70, 70, 186, 186), fill=(245, 245, 235, 255))
    for _ in range(14):
        a = random.uniform(0, 2 * math.pi)
        r = random.uniform(60, 115)
        x, y = 128 + r * math.cos(a), 128 + r * math.sin(a)
        s = random.uniform(6, 20)
        d.line((128, 128, x, y), fill=(245, 245, 235, 255), width=int(s))
        d.ellipse((x - s, y - s, x + s, y + s), fill=(245, 245, 235, 255))
    d.ellipse((105, 100, 150, 140), fill=(120, 110, 70, 255))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    save(img, "splat")

    # Speedometer.
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.pieslice((8, 8, 248, 248), 150, 390, fill=(0, 0, 0, 190), outline=WHITE, width=5)
    for i in range(11):
        a = math.radians(150 + i * 24)
        d.line((128 + 100 * math.cos(a), 128 + 100 * math.sin(a), 128 + 118 * math.cos(a), 128 + 118 * math.sin(a)), fill=RED if i > 7 else WHITE, width=5)
    tl = centered_text((256, 60), "MPH (MURLOCS/H)", font(ANTON, 22), WHITE, stroke=0, slant=0, shadow=False, rough=0)
    img.alpha_composite(tl, (0, 170))
    save(img, "speedo")
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon([(124, 128), (132, 128), (128, 24)], fill=RED)
    save(img, "speedo_needle")


# ---------------- sounds ----------------
SR = 44100


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, a=0.01, r=0.3):
    e = np.ones(n)
    an, rn = min(int(SR * a), n), min(int(SR * r), n)
    e[:an] = np.linspace(0, 1, an)
    if rn:
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def tone(f, dur, kind="sine", a=0.01, r=0.2):
    x = t(dur)
    ph = 2 * np.pi * f * x if np.isscalar(f) else 2 * np.pi * np.cumsum(f) / SR
    if kind == "square":
        w = np.sign(np.sin(ph)) * 0.5
    elif kind == "saw":
        w = 2 * ((ph / (2 * np.pi)) % 1) - 1
    elif kind == "brass":
        w = sum(np.sin(ph * k) / k ** 0.8 for k in range(1, 9))
    else:
        w = np.sin(ph)
    return w * env(len(x), a, r)


def bell(f, dur):
    x = t(dur)
    return sum(np.sin(2 * np.pi * f * m * x) * np.exp(-x * d) * g for m, d, g in [(1, 3, 1), (2.76, 5, 0.5), (5.4, 8, 0.3), (8.9, 12, 0.15)])


def noise(dur, decay=10):
    x = t(dur)
    return np.random.uniform(-1, 1, len(x)) * np.exp(-x * decay)


def reverb(sig, wet=0.3):
    out = np.copy(sig)
    for delay, g in [(0.029, 0.5), (0.037, 0.45), (0.051, 0.35), (0.083, 0.25), (0.121, 0.18)]:
        d = int(SR * delay)
        out[d:] += sig[:-d] * g * wet
    return out


def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts)
    out = np.zeros(n)
    for start, sig in parts:
        s = int(start * SR)
        out[s:s + len(sig)] += sig
    return out


LEVELS = {"high": 1.0, "med": 0.355, "low": 0.16}  # 0 dB, -9 dB, -16 dB


def write(sig, name):
    # Level by loudness (RMS), not peak, so short blips and long sirens sit at the same volume.
    rms = np.sqrt(np.mean(sig ** 2)) + 1e-9
    target = 0.045 if name.startswith("radio_") else 0.06
    sig = sig * (target / rms)
    peak = np.max(np.abs(sig))
    if peak > 0.5:
        sig = sig * (0.5 / peak)
    for level, gain in LEVELS.items():
        out = SND / level
        out.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp:
            wav = Path(tmp) / "x.wav"
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes((sig * gain * 32767).astype(np.int16).tobytes())
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(out / f"{name}.ogg")], check=True)


def chord(freqs, dur, kind="brass", r=0.6):
    return sum(tone(f, dur, kind, 0.02, r) for f in freqs)


def sounds():
    # Death sting: falling brass chord + low thump.
    sting = mix((0, chord([196, 233, 294], 0.5)), (0.45, chord([185, 220, 277], 0.5)), (0.9, chord([98, 116.5, 147, 174.6], 1.8, r=1.4)), (0.9, tone(np.linspace(80, 30, int(SR * 0.6)), 0.6, "sine", 0.001, 0.4) * 2))
    write(reverb(sting, 0.6), "death_sting")

    # Mission passed jingle: bright arpeggio into a held major chord.
    notes = [523, 659, 784, 1047]
    jingle = mix(*[(i * 0.13, tone(f, 0.25, "square", 0.005, 0.15) * 0.6) for i, f in enumerate(notes)], (0.55, chord([523, 659, 784, 1047], 1.2, "brass", 0.9)))
    write(reverb(jingle, 0.4), "mission_passed")

    # Mission failed: sad trombone.
    wah = mix(*[(i * 0.45, tone(f * (1 + 0.02 * np.sin(2 * np.pi * 6 * t(0.5 if i < 3 else 1.4))), 0.5 if i < 3 else 1.4, "brass", 0.03, 0.2)) for i, f in enumerate([293.7, 277.2, 261.6, 246.9])])
    write(wah, "mission_failed")

    # Cha-ching: drawer slide (noise) + two bells.
    write(mix((0, noise(0.15, 25) * 0.4), (0.08, bell(1760, 0.9)), (0.2, bell(2637, 1.0))), "cha_ching")

    # Wanted star up: short rising blip; star lost: falling blip.
    write(tone(np.linspace(600, 1400, int(SR * 0.12)), 0.12, "square", 0.002, 0.05), "star_up")
    write(tone(np.linspace(1200, 400, int(SR * 0.15)), 0.15, "square", 0.002, 0.08), "star_down")

    # Siren wail (3 cycles).
    x = t(3.0)
    write(tone(800 + 400 * np.sin(2 * np.pi * 0.9 * x), 3.0, "saw", 0.05, 0.4) * 0.5, "siren")

    # Phone ring (dual tone, ring-ring) and text ping.
    ring = tone(440, 0.4, "sine", 0.005, 0.02) + tone(480, 0.4, "sine", 0.005, 0.02)
    ring = ring * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 20 * t(0.4))))
    write(mix((0, ring), (0.6, ring)), "phone_ring")
    write(mix((0, bell(1568, 0.4)), (0.09, bell(2093, 0.5))), "text_ping")

    # Cheat activated: rising arpeggio sweep.
    write(mix(*[(i * 0.05, tone(300 * 2 ** (i / 4), 0.08, "square", 0.002, 0.03) * 0.5) for i in range(12)]), "cheat_activated")

    # Air horn.
    x = t(1.2)
    horn = sum(tone(f * (1 + 0.004 * np.sin(2 * np.pi * 5 * x)), 1.2, "saw", 0.01, 0.15) for f in [466, 554, 698])
    write(np.tanh(horn * 2), "airhorn")

    # Record scratch.
    x = t(0.5)
    f = 300 + 1800 * np.abs(np.sin(2 * np.pi * 3 * x))
    write(np.tanh((tone(f, 0.5, "saw", 0.002, 0.1) + noise(0.5, 2) * 0.6) * 1.5), "record_scratch")

    # Radio static / tune burst.
    st = np.convolve(np.random.uniform(-1, 1, int(SR * 0.7)), np.ones(4) / 4, "same") * env(int(SR * 0.7), 0.02, 0.2)
    write(st, "radio_static")

    # Bonk, boing, sploosh, vroom.
    write(mix((0, tone(np.linspace(900, 200, int(SR * 0.15)), 0.15, "sine", 0.001, 0.12)), (0, noise(0.05, 60) * 0.5)), "bonk")
    x = t(0.6)
    write(tone(300 + 250 * np.sin(2 * np.pi * 9 * x) * np.exp(-x * 4), 0.6, "sine", 0.002, 0.3), "boing")
    b = np.convolve(noise(0.8, 4), np.ones(30) / 30, "same")
    write(mix((0, b), (0.05, tone(np.linspace(500, 150, int(SR * 0.3)), 0.3, "sine", 0.002, 0.2) * 0.3)), "sploosh")
    x = t(1.6)
    rpm = 40 + 120 * (1 - np.exp(-x * 2))
    vroom = np.tanh(tone(rpm, 1.6, "saw", 0.05, 0.4) * 3 + tone(rpm * 2, 1.6, "square", 0.05, 0.4))
    write(vroom, "vroom")

    # Car horn (two-tone honk-honk).
    h = tone(415, 0.22, "square", 0.005, 0.03) + tone(523, 0.22, "square", 0.005, 0.03)
    write(np.tanh(mix((0, h), (0.3, h)) * 1.5), "honk")

    # Camera shutter: two sharp clicks.
    write(mix((0, noise(0.03, 150)), (0.07, noise(0.05, 90) * 0.8)), "shutter")

    # Slide whistle up and down.
    x = t(1.0)
    write(tone(600 + 900 * np.sin(np.pi * x), 1.0, "sine", 0.02, 0.1) * 0.7, "slide_whistle")

    # Police radio chirp.
    write(mix((0, tone(np.linspace(2000, 1200, int(SR * 0.08)), 0.08, "square", 0.001, 0.02) * 0.4), (0.1, noise(0.25, 6) * 0.3)), "police_chirp")

    # Level up fanfare.
    write(reverb(mix(*[(i * 0.12, tone(f, 0.22, "brass", 0.01, 0.1)) for i, f in enumerate([392, 523, 659, 784])], (0.5, chord([392, 523, 659, 784, 1047], 1.4, "brass", 1.0))), 0.5), "level_up")


def kick(dur=0.25):
    return tone(np.linspace(140, 40, int(SR * dur)), dur, "sine", 0.001, dur * 0.8) * 1.4


def hat(dur=0.05):
    return np.diff(np.concatenate([[0], noise(dur, 80)])) * 2


def snare(dur=0.18):
    return noise(dur, 25) * 0.6 + tone(190, dur, "sine", 0.001, dur * 0.9) * 0.4


def station(name, bpm, root, scale, lead_kind, swing, bars=8, seed=0):
    rng = random.Random(seed)
    beat = 60 / bpm
    step = beat / 2
    total = bars * 8 * step
    parts = []
    prog = [0, 5, 3, 4]
    for bar in range(bars):
        base = prog[bar % 4]
        for s in range(8):
            at = (bar * 8 + s) * step + (swing * step if s % 2 else 0)
            if s in (0, 4) or (s == 6 and bar % 2):
                parts.append((at, kick()))
            if s in (2, 6):
                parts.append((at, snare()))
            parts.append((at, hat() * 0.5))
            bass_deg = scale[(base + (0 if s < 4 else 4)) % len(scale)]
            if s % 2 == 0:
                parts.append((at, tone(root / 2 * 2 ** (bass_deg / 12), step * 1.8, "saw", 0.005, 0.08) * 0.35))
            if rng.random() < 0.6:
                deg = scale[(base + rng.choice([0, 2, 4, 5, 7])) % len(scale)] + 12 * rng.choice([0, 0, 1])
                parts.append((at, tone(root * 2 ** (deg / 12), step * 0.9, lead_kind, 0.005, 0.06) * 0.25))
    sig = mix(*parts)[: int(total * SR)]
    write(reverb(sig, 0.25), name)


def radio():
    major = [0, 2, 4, 5, 7, 9, 11]
    minor = [0, 2, 3, 5, 7, 8, 10]
    dorian = [0, 2, 3, 5, 7, 9, 10]
    station("radio_goblin_funk", 104, 220, dorian, "square", 0.18, seed=1)
    station("radio_murloc_wave", 118, 262, minor, "saw", 0.0, seed=2)
    station("radio_elwynn_lofi", 78, 196, major, "sine", 0.25, seed=3)


if __name__ == "__main__":
    textures()
    sounds()
    radio()
    print("textures:", len(list(TEX.glob("*.png"))), "sounds:", len(list(SND.glob("*/*.ogg"))))
