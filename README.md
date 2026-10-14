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

## Getting found (search engines and AI assistants)
`scripts/build_pages.rb` turns the verified case files into plain HTML pages that Google, Bing and AI
crawlers can read: `site/cases/<id>/` (English) and `site/fr|es|ar|zh/cases/<id>/`, plus hub pages by type
and country, `sitemap.xml`, `llms.txt` and `cases/feed.xml`. The robot runs it after every wire update and
pings Bing (IndexNow) with the pages that changed, so an approved draft gets its page within 30 minutes.
Nothing to do by hand; if you edit a case file locally you can run `ruby scripts/build_pages.rb` to preview
the pages, but the robot will rebuild them anyway.

The strategy, the account steps (Google Search Console, Bing Webmaster Tools, dataset mirrors) and the
weekly checklist are in `GROWTH.md`.

## If the 30-minute schedule misses runs
GitHub's free scheduler is best-effort: it can delay or skip cron runs for an hour or more. If the
"Updated N min ago" stamp on the site keeps drifting past 40 minutes, add an outside timer that presses
the "Run workflow" button for you:
1. github.com → your avatar → Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
   → Generate new token. Name `aithreat-cron`, expiration 1 year, Repository access: only `aithreat`,
   Permissions → Repository permissions → **Actions: Read and write**. Generate and copy the token.
2. Create a free account at cron-job.org → Create cronjob:
   - URL: `https://api.github.com/repos/karlabouzeid/aithreat/actions/workflows/update.yml/dispatches`
   - Schedule: every 30 minutes (minutes 5 and 35)
   - Advanced → Request method **POST**; Headers: `Authorization: Bearer <the token>`,
     `Accept: application/vnd.github+json`; Request body: `{"ref":"main"}`
3. Save. Each ping starts a run within seconds; GitHub shows them as "Manually run" via API.
The token lives only in cron-job.org; never paste it anywhere else.

## Changing sources
Edit `config/feeds.json`. Each entry is a name and an RSS/Atom URL. `"ai_only": true` means every item from that feed counts as AI-related without keyword checks.
