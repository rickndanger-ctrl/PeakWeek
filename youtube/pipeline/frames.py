"""Render a Real or Machine script into the still frames of a vertical Short.

Every scene is one PNG. build.py holds each one on screen for as long as its
narration lasts, so nothing here needs to know about timing.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import config as C


# --- font loading ------------------------------------------------------------

_cache: dict = {}


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    key = (kind, size)
    if key in _cache:
        return _cache[key]
    paths = {"display": C.DISPLAY_FONTS, "serif": C.SERIF_FONTS, "mono": C.MONO_FONTS}[kind]
    for p in paths:
        if Path(p).exists():
            try:
                f = ImageFont.truetype(p, size)
                _cache[key] = f
                return f
            except OSError:
                continue
    raise RuntimeError(
        f"No usable {kind} font found. Checked: {paths}. "
        "Add a path that exists on this machine to config.py."
    )


# --- text helpers ------------------------------------------------------------

def _width(draw, text, f) -> float:
    return draw.textbbox((0, 0), text, font=f)[2]


def wrap(draw, text: str, f, max_w: int) -> list[str]:
    """Word-wrap to a pixel width, honouring newlines already in the text."""
    lines: list[str] = []
    for para in text.split("\n"):
        if not para.strip():
            lines.append("")
            continue
        words, cur = para.split(), ""
        for w in words:
            trial = f"{cur} {w}".strip()
            if _width(draw, trial, f) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    return lines


def fit_block(draw, text: str, kind: str, max_w: int, max_h: int,
              start: int, floor: int = 30) -> tuple[ImageFont.FreeTypeFont, list[str], int]:
    """Shrink the type until the wrapped block fits the box. Returns font, lines, line height."""
    for size in list(range(start, floor, -3)) + [floor]:
        f = font(kind, size)
        lines = wrap(draw, text, f, max_w)
        lh = int(size * 1.42)
        if len(lines) * lh <= max_h and all(_width(draw, line, f) <= max_w for line in lines):
            return f, lines, lh
    raise ValueError("Text does not fit at a readable size; shorten it before rendering.")


def draw_block(draw, lines, f, lh, x, y, fill, align="left", max_w=None) -> int:
    for line in lines:
        if line:
            dx = x
            if align == "center" and max_w:
                dx = x + (max_w - _width(draw, line, f)) / 2
            draw.text((dx, y), line, font=f, fill=fill)
        y += lh
    return y


def fit_unwrapped(draw, text: str, kind: str, max_w: int, max_h: int,
                  start: int, floor: int = 28) -> tuple[ImageFont.FreeTypeFont, list[str], int] | None:
    """Fit text with its own line breaks intact — no word wrapping.

    Verse and dialogue break where the author broke them, so re-wrapping a poem
    to the frame width destroys the thing the video is asking people to judge.
    Returns None when the text cannot fit unwrapped even at the floor size.
    """
    src = [ln for ln in text.split("\n")]
    size = start
    while size >= floor:
        f = font(kind, size)
        lh = int(size * 1.5)
        if len(src) * lh <= max_h and all(_width(draw, ln, f) <= max_w for ln in src):
            return f, src, lh
        size -= 2
    return None


# Verse is set unwrapped, so these three move together: a line short enough to
# be called verse has to still fit across the card at the smallest type we will
# set. At 32px, 48 characters of ordinary English measure ~640px against 968px
# of card, which leaves comfortable headroom — but character width varies, so
# this is sizing for the common case, not a proof. scene_specimen still raises
# on the rare line that will not fit, rather than silently rewrapping a poem.
VERSE_LINE_MAX = 48
VERSE_FLOOR_PX = 32
SPECIMEN_MARGIN = 56  # narrower than the page margin: verse needs the width


def is_verse(text: str) -> bool:
    """Whether the author's own line breaks carry meaning worth preserving.

    Verse breaks its lines early and deliberately; prose only breaks between
    sentences or paragraphs, at whatever length the sentence happened to run.
    A passage counts as verse when it breaks at all and every one of its lines
    is short enough to have been an intentional break.
    """
    lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
    return len(lines) > 1 and all(len(ln) <= VERSE_LINE_MAX for ln in lines)


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (C.WIDTH, C.HEIGHT), C.BONE)
    return img, ImageDraw.Draw(img)


def _eyebrow(draw, text, color=C.MUTED, y=None):
    f = font("mono", 30)
    y = C.MARGIN if y is None else y
    draw.text((C.MARGIN, y), text.upper(), font=f, fill=color)
    return y + 52


def _wordmark(draw):
    """Bottom-left channel mark, on every frame."""
    f = font("display", 30)
    y = C.HEIGHT - C.MARGIN - 30
    draw.text((C.MARGIN, y), "REAL OR ", font=f, fill=C.MUTED)
    w = _width(draw, "REAL OR ", f)
    draw.text((C.MARGIN + w, y), "MACHINE", font=f, fill=C.KILN)


# --- scenes ------------------------------------------------------------------

def scene_hook(text: str) -> Image.Image:
    img, d = _canvas()
    inner = C.WIDTH - 2 * C.MARGIN
    f, lines, lh = fit_block(d, text, "display", inner, 900, 96, 52)
    y = (C.HEIGHT - len(lines) * lh) / 2 - 60
    draw_block(d, lines, f, lh, C.MARGIN, y, C.INK)
    d.rectangle([C.MARGIN, y + len(lines) * lh + 46, C.MARGIN + 150, y + len(lines) * lh + 54], fill=C.KILN)
    _wordmark(d)
    return img


def scene_specimen(specimen: str) -> Image.Image:
    img, d = _canvas()
    _eyebrow(d, "Human or machine?", C.KILN)

    margin = SPECIMEN_MARGIN
    inner = C.WIDTH - 2 * margin
    avail_h = C.HEIGHT - 560

    # Verse must keep every original line. Stop for editorial review if it
    # cannot fit legibly instead of silently changing the poem's line breaks.
    #
    # A newline alone does not make a passage verse: prose specimens carry them
    # between sentences and paragraphs, and those lines are far too long to set
    # unwrapped. Verse breaks early, so short source lines are the signal —
    # wrapping a prose paragraph loses nothing a viewer is being asked to judge.
    if is_verse(specimen):
        got = fit_unwrapped(d, specimen, "serif", inner, avail_h, 68, VERSE_FLOOR_PX)
        if got is None:
            raise ValueError(
                "Specimen lines do not fit legibly without rewrapping; review the script. "
                f"Verse lines must be at most {VERSE_LINE_MAX} characters."
            )
        f, lines, lh = got
    else:
        f, lines, lh = fit_block(d, specimen, "serif", inner, avail_h, 60, 30)

    pad = 64
    block_h = len(lines) * lh
    card_top = (C.HEIGHT - block_h) / 2 - pad - 40
    card_bottom = card_top + block_h + 2 * pad
    d.rectangle([margin - 24, card_top, C.WIDTH - margin + 24, card_bottom], fill=C.SURFACE)
    d.rectangle([margin - 24, card_top, margin - 16, card_bottom], fill=C.KILN)
    draw_block(d, lines, f, lh, margin, card_top + pad, C.INK)
    _wordmark(d)
    return img


def scene_count(n: int) -> Image.Image:
    img, d = _canvas()
    f = font("display", 380)
    s = str(n)
    w = _width(d, s, f)
    d.text(((C.WIDTH - w) / 2, C.HEIGHT / 2 - 260), s, font=f, fill=C.KILN)
    _wordmark(d)
    return img


def scene_answer(answer: str, attribution: str) -> Image.Image:
    img, d = _canvas()
    human = answer == "human"
    color = C.HUMAN if human else C.SYNTH
    label = "HUMAN" if human else "MACHINE"

    inner = C.WIDTH - 2 * C.MARGIN
    got = fit_unwrapped(d, label, "display", inner, 300, 190, 100)
    if got is None:
        raise ValueError(
            f"'{label}' will not fit the answer card above 100px on this machine's "
            "display font. Lower the floor in scene_answer or pick a narrower face."
        )
    f, _, _ = got
    w = _width(d, label, f)
    y = C.HEIGHT / 2 - 340
    d.text(((C.WIDTH - w) / 2, y), label, font=f, fill=color)
    d.rectangle([(C.WIDTH - w) / 2, y + 250, (C.WIDTH + w) / 2, y + 260], fill=color)

    af, lines, lh = fit_block(d, attribution, "serif", inner, 320, 52, 30)
    draw_block(d, lines, af, lh, C.MARGIN, y + 330, C.INK_SOFT, align="center", max_w=inner)
    _wordmark(d)
    return img


def scene_tell(tell: str) -> Image.Image:
    img, d = _canvas()
    y = _eyebrow(d, "The tell", C.KILN)
    inner = C.WIDTH - 2 * C.MARGIN
    f, lines, lh = fit_block(d, tell, "display", inner, C.HEIGHT - y - 420, 64, 34)
    top = y + (C.HEIGHT - y - 300 - len(lines) * lh) / 2
    draw_block(d, lines, f, lh, C.MARGIN, top, C.INK)
    _wordmark(d)
    return img


def scene_cta(cta: str) -> Image.Image:
    img, d = _canvas()
    inner = C.WIDTH - 2 * C.MARGIN
    f, lines, lh = fit_block(d, cta, "display", inner, 620, 76, 40)
    y = C.HEIGHT / 2 - len(lines) * lh / 2 - 80
    draw_block(d, lines, f, lh, C.MARGIN, y, C.INK, align="center", max_w=inner)

    mf = font("mono", 34)
    tag = "NEW SPECIMEN 3x DAILY"
    w = _width(d, tag, mf)
    d.text(((C.WIDTH - w) / 2, y + len(lines) * lh + 70), tag, font=mf, fill=C.KILN)
    _wordmark(d)
    return img


# --- the sequence ------------------------------------------------------------

def build_scenes(script: dict, out_dir: Path) -> list[dict]:
    """Render every frame and return the scene list build.py needs.

    Each scene is {"png": Path, "say": str|None, "min": float}. A scene with
    "say" set is held for as long as the narration runs; the rest use "min".
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    answer = script.get("answer", "ai")
    attribution = script.get("attribution") or (
        "Written by an AI for this game" if answer == "ai" else ""
    )
    scenes: list[dict] = []

    def add(name: str, img: Image.Image, say: str | None, minimum: float):
        p = out_dir / f"{len(scenes):02d}-{name}.png"
        img.save(p)
        scenes.append({"png": p, "say": say, "min": minimum})

    add("hook", scene_hook(script["hook"]), script["hook"], C.HOOK_MIN)
    add("specimen", scene_specimen(script["specimen"]), script["specimen"], C.SPECIMEN_MIN)
    for n in (3, 2, 1):
        add(f"count{n}", scene_count(n), None, C.COUNTDOWN_EACH)
    spoken_answer = "Human." if answer == "human" else "A machine wrote it."
    add("answer", scene_answer(answer, attribution), spoken_answer, C.ANSWER_HOLD)
    add("tell", scene_tell(script["tell"]), script["tell"], C.TELL_MIN)
    cta = script.get("cta") or "Play the daily set. Link in bio."
    add("cta", scene_cta(cta), cta, C.CTA_MIN)
    return scenes
