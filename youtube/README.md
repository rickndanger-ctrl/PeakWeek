# Real or Machine — autonomous channel

A daily guessing game plus the content pipeline that feeds a YouTube Shorts channel.

Viewers read a short passage and decide whether a person or a machine wrote it,
then learn the specific tell. Every "human" specimen is genuine public-domain
writing (pre-1930) with a real attribution; every "machine" specimen is written
fresh by an AI for the game. No scraped text, no copyright exposure.

## Live pages
- Game: https://claude.ai/code/artifact/79e4a7e8-8a5c-42b8-872d-f60a4aa4cbeb
- Production desk: https://claude.ai/code/artifact/e02a6468-51e7-4650-8904-2d31a03820c7

`game.html` and `desk.html` are the sources for those two pages. Republishing
either one to its URL updates the live page in place.

## Scheduled jobs (all times US Eastern)
| Slot | Fires | Does |
|---|---|---|
| Morning | 7:00am | Writes one Short script to the desk |
| Afternoon | 1:00pm | Writes one Short script (the argumentative one) |
| Evening | 7:00pm | Writes one Short script, then adds two new specimens to the game |

Each run appends a document to the desk's `scripts` collection. The desk page
reads that collection live, so new scripts appear without a redeploy.

## Script schema (`scripts/<YYYY-MM-DD>-<slot>`)
date, slot, createdAt, posted, answer ("human" | "ai"), specimen, attribution,
hook, tell, title, caption, cta, tags[]

## Game corpus
`CORPUS` in `game.html`. Entries are `{c, src, by?, t, tell}` — `src` is
`"human"` or `"ai"`, `by` is the attribution (human entries only), `tell`
allows `<b>` on the giveaway phrase. Five specimens per day, date-seeded, so
every player sees the same set.

## Not yet automated
Uploading to YouTube. That needs a Google Cloud project with the YouTube Data
API enabled and an OAuth refresh token; until those exist, scripts stack up on
the desk and get posted by hand.
