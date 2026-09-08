#!/usr/bin/env python3
"""One-time YouTube authorisation. Run this once, then never again.

    python3 auth.py

It opens a browser, asks you to pick the channel's Google account, and saves a
refresh token to ~/.realormachine/token.json. Nothing is printed to the screen
and nothing is written into the repository.
"""

import sys

import config as C
import upload

if __name__ == "__main__":
    try:
        path = upload.authorize()
    except Exception as e:
        print(f"Authorisation failed: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"Authorised. Token saved to {path}")
    print(f"Uploads will be {C.PRIVACY}. Change PRIVACY in config.py to alter that.")
