"""YouTube authorisation and upload.

Run `python3 auth.py` once to authorise. After that the refresh token in
~/.realormachine/token.json keeps working unattended.
"""

import random
import time
from pathlib import Path

import config as C


def _client():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    if not C.TOKEN_FILE.exists():
        raise RuntimeError(
            f"Not authorised yet — {C.TOKEN_FILE} is missing. Run: python3 auth.py"
        )
    creds = Credentials.from_authorized_user_file(str(C.TOKEN_FILE), C.YOUTUBE_SCOPES)
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            C.TOKEN_FILE.write_text(creds.to_json())
        else:
            raise RuntimeError("Stored credentials are no longer valid. Run: python3 auth.py")
    return build("youtube", "v3", credentials=creds, cache_discovery=False)


def authorize() -> Path:
    """One-time browser consent. Writes the refresh token and returns its path."""
    from google_auth_oauthlib.flow import InstalledAppFlow

    if not C.CLIENT_SECRET.exists():
        raise RuntimeError(
            f"Missing {C.CLIENT_SECRET}.\n"
            "Download the OAuth client JSON from Google Cloud Console and save it there. "
            "See SETUP.md."
        )
    C.SECRETS_DIR.mkdir(parents=True, exist_ok=True)
    flow = InstalledAppFlow.from_client_secrets_file(str(C.CLIENT_SECRET), C.YOUTUBE_SCOPES)
    creds = flow.run_local_server(port=0, prompt="consent", access_type="offline")
    C.TOKEN_FILE.write_text(creds.to_json())
    C.TOKEN_FILE.chmod(0o600)
    return C.TOKEN_FILE


def upload(video: Path, script: dict) -> str:
    """Upload one Short. Returns the video id."""
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload

    youtube = _client()
    tags = [t.lstrip("#") for t in script.get("tags", [])]
    description = "\n\n".join(filter(None, [
        script.get("caption", ""),
        f"Answer: {'Human' if script.get('answer') == 'human' else 'Machine'}"
        + (f" — {script['attribution']}" if script.get("attribution") else ""),
        script.get("tell", ""),
        "Human specimens are public-domain writing, credited above. "
        "Machine specimens were written by an AI for this channel.",
        " ".join(script.get("tags", [])),
    ]))

    body = {
        "snippet": {
            "title": script["title"][:100],
            "description": description[:4900],
            "tags": tags[:15],
            "categoryId": C.CATEGORY_ID,
        },
        "status": {"privacyStatus": C.PRIVACY, "selfDeclaredMadeForKids": False},
    }
    media = MediaFileUpload(str(video), chunksize=-1, resumable=True, mimetype="video/mp4")
    request = youtube.videos().insert(part="snippet,status", body=body, media_body=media)

    response, attempt = None, 0
    while response is None:
        try:
            _, response = request.next_chunk()
        except HttpError as e:
            # 5xx and 429 are worth retrying; anything else is a real error.
            if e.resp.status not in (429, 500, 502, 503, 504) or attempt >= 5:
                raise
            attempt += 1
            time.sleep(min(2 ** attempt + random.random(), 60))
    return response["id"]
