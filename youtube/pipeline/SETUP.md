# YouTube upload setup

One-time setup, on your Mac. Budget 20 minutes. After this the channel posts
without you.

Everything secret stays in `~/.realormachine/` — outside the repository, so
nothing sensitive is ever committed or pushed.

---

## Step 1 — Install the tools (5 min)

Open Terminal and paste these one at a time.

```
brew install ffmpeg
```

If `brew` isn't found, install Homebrew first from https://brew.sh, then re-run
the line above. `ffmpeg` is what stitches the frames and the voiceover into a
video.

```
cd ~/PeakWeek/youtube/pipeline
pip3 install -r requirements.txt
```

That installs the image renderer and Google's API libraries.

---

## Step 2 — Make a Google Cloud project (5 min)

1. Go to https://console.cloud.google.com/projectcreate
2. Project name: `Real or Machine`. Click **Create**. Wait for it to finish.
3. Make sure the new project is selected in the dropdown at the top of the page.

## Step 3 — Turn on the YouTube API (1 min)

1. Go to https://console.cloud.google.com/apis/library/youtube.googleapis.com
2. Click **Enable**.

## Step 4 — Set up the consent screen (5 min)

1. Go to https://console.cloud.google.com/auth/overview
2. Click **Get started**.
3. App name: `Real or Machine`. User support email: your own address. **Next**.
4. Audience: choose **External**. **Next**.
5. Contact email: your own address. **Next**. Agree, then **Create**.
6. In the left menu click **Audience**. Under **Test users**, click
   **+ Add users**, enter the Google account that owns the YouTube channel, and
   **Save**.

> Leaving the app in "testing" mode is fine — it's only ever you signing in.
> Google expires test-mode refresh tokens after 7 days, so once you're happy
> the pipeline works, come back to **Audience** and click **Publish app**.
> You do not need Google's verification review for uploads to your own channel.

## Step 5 — Create the credentials (3 min)

1. Go to https://console.cloud.google.com/auth/clients
2. Click **+ Create client**.
3. Application type: **Desktop app**. Name: `Real or Machine uploader`.
   Click **Create**.
4. In the popup, click **Download JSON**.
5. Move the downloaded file into place and lock it down — paste this into
   Terminal, adjusting the filename to match what actually landed in Downloads:

```
mkdir -p ~/.realormachine
mv ~/Downloads/client_secret_*.json ~/.realormachine/client_secret.json
chmod 600 ~/.realormachine/client_secret.json
```

## Step 6 — Authorise, once (2 min)

```
cd ~/PeakWeek/youtube/pipeline
python3 auth.py
```

A browser window opens. Pick the Google account that owns the channel. Google
will warn that the app isn't verified — click **Advanced**, then
**Go to Real or Machine (unsafe)**. That warning is expected: the "unverified
app" is the one you just created for yourself. Approve the upload permission.

You should see `Authorised. Token saved to …`. That's the last manual step.

---

## Step 7 — Test it before it goes live

Set `PRIVACY = "private"` in `config.py`, then:

```
python3 run.py --one
```

It renders the oldest pending script and uploads it privately. Open YouTube
Studio and watch it. If it looks right, set `PRIVACY = "public"` and delete the
test video.

To render without uploading anything at all:

```
python3 run.py --dry-run
```

The mp4 lands in `youtube/build/<script-name>/short.mp4`.

---

## Step 8 — Put it on a schedule

The scheduled Claude jobs write a new script at 7am, 1pm and 7pm. This runs
half an hour after each, giving the script time to land.

```
cp com.realormachine.pipeline.plist ~/Library/LaunchAgents/
```

Open `~/Library/LaunchAgents/com.realormachine.pipeline.plist` in TextEdit and
replace every `/Users/YOURNAME` with your real home folder path (run `echo $HOME`
in Terminal if you're unsure). Save, then:

```
launchctl load ~/Library/LaunchAgents/com.realormachine.pipeline.plist
```

Done. Check on it any time with:

```
tail -30 ~/PeakWeek/youtube/build/pipeline.log
```

To stop it:

```
launchctl unload ~/Library/LaunchAgents/com.realormachine.pipeline.plist
```

---

## Things that will eventually go wrong

**"Not authorised yet — token.json is missing"**
Step 6 didn't complete. Run `python3 auth.py` again.

**"Stored credentials are no longer valid"**
The refresh token expired — this happens after 7 days while the app is in
testing mode. Publish the app (end of Step 4), then run `python3 auth.py` once
more.

**"`ffmpeg` is not installed"**
Step 1. `brew install ffmpeg`.

**Uploads stop with a quota error**
YouTube allows roughly six uploads a day on a fresh project's quota. Three a
day sits comfortably inside it. If you raise the posting rate you'll need to
request more quota from Google.

**Videos upload but the channel gets no views for the first two weeks**
Normal. Shorts distribution takes time to find a new channel's audience. Don't
change the format on week one — the archive is what starts working later.
