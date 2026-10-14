# AI Threat Watch — site and 30-minute updater

This folder is the whole website plus the robot that keeps it fresh.

```
site/                 the website (what Netlify publishes)
  index.html          the page
  i18n/               French, Spanish, Arabic, Chinese case files
  data/               incidents.en.json (verified case files), wire.json (headlines),
                      candidates.json (auto-drafted, unverified), status.json
scripts/update.rb     the updater: pulls 17 security feeds, keeps AI-security stories,
                      asks Claude to triage them and draft case files for new incidents
config/feeds.json     the list of news sources
config/approved.txt   ids of drafts you have checked and want published as verified
config/rejected.txt   ids of drafts you want removed
.github/workflows/    tells GitHub to run the updater every 30 minutes
```

## One-time setup (about 20 minutes)

### 1. Put the folder on GitHub
1. Create a free account at github.com if you don't have one.
2. Install GitHub Desktop (desktop.github.com) and sign in.
3. In GitHub Desktop: File → Add Local Repository → choose this `aithreat` folder → "Publish repository". Keep it **private** or public, either works. Name: `aithreat`.

### 2. Give the robot its key
1. Go to console.anthropic.com → API Keys → Create key. Copy it.
   (Cost: the updater runs 48 times a day; expect roughly $5–15 per month.)
2. On github.com open your `aithreat` repository → Settings → Secrets and variables → Actions → "New repository secret".
   Name: `ANTHROPIC_API_KEY`. Value: paste the key. Save.
3. Still in the repository: Actions tab → if GitHub asks, click "I understand my workflows, go ahead and enable them".
4. Actions → "Update wire every 30 minutes" → "Run workflow" to test it once. Green check = working.

### 3. Point Netlify at GitHub (so every update goes live automatically)
1. app.netlify.com → your site → Site configuration → Build & deploy → "Link repository" (or create a new site from Git and move the domain to it).
2. Choose GitHub → `aithreat`. Build command: leave empty. Publish directory: `site`. Deploy.
3. From now on every change on GitHub (including the robot's every-30-minutes updates) is live within a minute. You no longer drag folders.

## Day to day: reviewing drafts
The robot drafts a case file for anything that looks like a real new incident. Drafts appear on the site as **Unverified · auto-drafted** with dashed markers. To review them:
1. Open the site → Live wire → "Open draft case file", read the source.
2. To publish it as verified: on github.com open `config/approved.txt` → pencil icon → add the draft's id (shown as "Case …" at the top of the case file) on its own line → "Commit changes".
3. To remove a bad draft: add its id to `config/rejected.txt` the same way.
The next run (within 30 minutes) applies your decisions. Unreviewed drafts expire after 30 days.

## Changing sources
Edit `config/feeds.json`. Each entry is a name and an RSS/Atom URL. `"ai_only": true` means every item from that feed counts as AI-related without keyword checks.
