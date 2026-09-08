"""Shared settings for the Real or Machine video pipeline."""

from pathlib import Path

# --- where things live -------------------------------------------------------
REPO = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO / "youtube" / "scripts"      # one JSON per Short, written by the scheduled jobs
BUILD_DIR = REPO / "youtube" / "build"          # rendered frames and mp4s (git-ignored)
STATE_FILE = REPO / "youtube" / "build" / "uploaded.json"

# Secrets live outside the repo so they are never committed.
SECRETS_DIR = Path.home() / ".realormachine"
CLIENT_SECRET = SECRETS_DIR / "client_secret.json"   # downloaded from Google Cloud Console
TOKEN_FILE = SECRETS_DIR / "token.json"              # written by auth.py, refreshed automatically

# --- canvas ------------------------------------------------------------------
WIDTH, HEIGHT = 1080, 1920
FPS = 30
MARGIN = 96

# --- palette (matches the game and the desk) ---------------------------------
BONE = (14, 18, 17)
SURFACE = (23, 28, 26)
INK = (233, 237, 233)
INK_SOFT = (195, 202, 197)
MUTED = (139, 149, 143)
RULE = (44, 52, 49)
HUMAN = (95, 196, 141)
SYNTH = (169, 139, 255)
KILN = (232, 129, 75)

# --- fonts -------------------------------------------------------------------
# First path that exists wins. macOS paths first, Linux fallbacks after, so the
# same code renders on a laptop and in a container.
DISPLAY_FONTS = [
    "/System/Library/Fonts/Supplemental/Futura.ttc",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
SERIF_FONTS = [
    "/System/Library/Fonts/Supplemental/Georgia.ttf",
    "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
]
MONO_FONTS = [
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Supplemental/Courier New.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
]

# --- voice -------------------------------------------------------------------
# `say -v '?'` lists what is installed. Ava and Samantha are the usual good ones.
VOICE = "Ava"
VOICE_RATE = 178          # words per minute
FALLBACK_VOICE = "Samantha"

# --- timing (seconds) --------------------------------------------------------
HOOK_MIN = 2.0
SPECIMEN_MIN = 6.0
COUNTDOWN_EACH = 0.8
ANSWER_HOLD = 1.6
TELL_MIN = 6.0
CTA_MIN = 1.8
SCENE_PAD = 0.35          # breath added after each narrated scene

# --- upload ------------------------------------------------------------------
YOUTUBE_SCOPES = ["https://www.googleapis.com/auth/youtube.upload"]
PRIVACY = "public"        # "private" or "unlisted" while you are testing
CATEGORY_ID = "27"        # Education
