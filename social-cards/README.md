# Partridg3 Social Hero Cards

Reusable system for producing branded, 1080x1080 social-media cards for Instagram/Facebook, built 2026-08-19. Two audiences, two content files, one shared template.

## Files

- **`hero-card-template.html`** — the canonical card template. Forest/gold brand tokens matching `../brochure.html`/`../index.html`, real Partridg3 bird logo (from `P3Logo.tsx`). Content is swapped in via a `?cfg=<JSON>` query param.
- **`cards.json`** — client-side card content (benefits, calculators, Covey features, ways to share, booking, the digital brochure). Each entry has an `id`, `category`, real `destination` URL, and a `cfg` object matching the template's fields.
- **`cards-adviser.json`** — adviser-recruitment card content (benefits of joining, adviser tooling, referring a colleague, applying).
- **`generate-cards.mjs`** — renders every card in a given `*.json` file to a PNG via headless Chrome. See usage below.
- **`output/`**, **`output-adviser/`** — the rendered PNGs plus a `manifest.json` and `POSTING-GUIDE.md` (which file → which real link to post it with).
- **`CONTENT-CLIENT.md`**, **`CONTENT-ADVISER.md`** — the same content in plain-language, human-readable form (no HTML/JSON) for review or handing to a copywriter.

## Regenerating cards

```
# one-time per session, in this directory:
python -m http.server 8765

# in another terminal:
node generate-cards.mjs                              # cards.json -> output/
node generate-cards.mjs cards-adviser.json output-adviser
node generate-cards.mjs cards.json output some-id.json  # (edit cards.json to filter first if you only want one card)
```

Requires a local Chrome or Edge install (checked automatically — see `CHROME_CANDIDATES` in the script). The two-step server+generate process is deliberate: an all-in-one self-hosting version was tried and hung unreliably; the external static server is the proven-stable approach.

## Adding a new card

1. Add an entry to `cards.json` or `cards-adviser.json` — copy an existing one, change `id`, `category`, `destination`, and the `cfg` fields (`eyebrow`, `category`, `headline` — HTML allowed for `<span class="hl">`, `subhead`, `cta`, `footer`, `stats`).
2. Regenerate (see above).
3. Update the matching `CONTENT-*.md` and `POSTING-GUIDE.md` (or ask Claude to do both from the updated JSON).

## Real-link discipline

Every `destination` in both JSON files is a real, currently-live URL — verified during a code audit, not assumed. Notably:
- Calculator cards deep-link to a specific tool tab via `#tools-<id>` (a small hash-routing addition to `index.html`, since the tools UI has no native URL routing).
- Booking cards route to Covey's real adviser-availability system (`/book`), not the still-unconfigured WhatsApp direct-message number (`27000000000` — a placeholder, not a real adviser line).
- Adviser-recruitment cards route to `landing/#contact`, since no dedicated "apply to become an adviser" page exists yet — flagged in `CONTENT-ADVISER.md`.

If any of these change (a real WhatsApp number gets set up, a dedicated adviser-application page ships, etc.), update the `destination` fields and regenerate — the images don't show the raw URL, so old images stay usable as long as the caption/bio link is updated.
