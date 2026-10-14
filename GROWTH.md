# Growth plan: getting aithreat.io found

Written 14 October 2026. Companion to the research synthesis at
https://claude.ai/artifact/2NTWb4bPSWSy6jJsCQPHCG (audiences, 90-day plan, launch playbook).
This file is the practical "how do people find us" plan, and the checklist of account steps only you can do.

## The three questions, answered

**Should I start with Google?**
Yes, but do Google and Bing on the same day. Google is where journalists, analysts and students search.
Bing matters more than its market share suggests: Microsoft Copilot runs on it, and Bing Webmaster Tools
is currently the only place that shows you *which of your pages AI answers cite*. Both are free and take
about ten minutes each (steps below). Do not buy Google Ads: a free reference site earns nothing per visit,
and paid clicks do not build the citations that make a reference site.

**Can the site be recommended when people ask ChatGPT, Perplexity, Claude or Gemini?**
Yes, and there is no paid placement for it. AI assistants recommend and cite pages that are
(1) crawlable as plain HTML, (2) indexed by Bing or Google, (3) written as self-contained, quotable answers,
and (4) mentioned on other credible sites. Until today the site failed test 1: it was one page that drew
every case file in the browser with JavaScript, so a crawler saw a title and an empty shell. That is fixed
(see "What changed today"). Tests 2 to 4 are the work of the next 90 days.

**How do I drive visibility organically?**
Three engines, in this order of payoff:
1. **Pages that answer a question.** Each case file is now its own page in five languages, with a stable
   address. Next: hub pages per attack type and per country exist; add per-company pages and a glossary.
2. **Being cited.** Open data, a permanent link and a ready-made citation on every case. Mirror the dataset
   on GitHub and Hugging Face. Get into Wikipedia references where a case has an article.
3. **Distribution.** Newsletters and LinkedIn carousels beat X for this audience. Show HN and Product Hunt
   once alerts exist to catch the spike. Details in the launch playbook linked above.

## What changed today (already in the repo, live when you push)

| Change | Why it matters |
| --- | --- |
| `site/cases/<id>/` pages for all 57 verified cases, plus `/fr/`, `/es/`, `/ar/`, `/zh/` versions (390 pages) | Google, Bing and AI crawlers can finally read the content. hreflang tags tell Google which language to show whom. |
| Hub pages: `/cases/`, `/cases/category/<type>/`, `/cases/country/<cc>/` in every language | Search magnets for "prompt injection incidents", "AI deepfake fraud cases", "AI security incidents Italy". |
| `sitemap.xml` with language alternates | What you submit to Google and Bing. |
| `robots.txt` | Welcomes all crawlers, including AI search bots; hides the raw wire JSON from results. |
| `llms.txt` | A plain-text map of the site for AI agents (adoption is growing; cost is zero). |
| JSON-LD structured data: Article + breadcrumbs on each case, WebSite + Organization + **Dataset** on the homepage | The Dataset block gets the data into Google Dataset Search, which researchers use. |
| Open Graph and Twitter cards with the brand image (`assets/brand/og-image.png`) | Links shared on LinkedIn, Slack and X now unfurl with a proper preview. |
| "Copy link" in the map now copies the permanent page address | Every share becomes a crawlable backlink to a real page. |
| `/cases/feed.xml` (verified case files RSS, per language) | Lets newsletters, Slack and Feedly subscribe to verified cases only, separate from the noisy wire. |
| CORS headers on `/data/*` | Notebooks and other sites can load the JSON directly. |
| IndexNow: the robot tells Bing which pages changed after every run | New case files appear in Bing and Copilot within minutes, not weeks. |
| A proper 404 page | Broken links send people to the case list instead of a Netlify error. |
| Licence stated on every page: CC BY 4.0 | Reuse with attribution is what gets a dataset embedded and cited. Change the wording in `scripts/build_pages.rb` if you want a different licence. |

The page generator is `scripts/build_pages.rb`. The GitHub robot runs it every 30 minutes after the wire
update, so a case you approve gets its pages automatically. Output is identical for identical input, so it
never creates noise commits.

## Account steps only you can do (about 40 minutes total)

Do these after you push today's changes with GitHub Desktop and Netlify shows the deploy as published.
Check first that https://aithreat.io/cases/ and https://aithreat.io/sitemap.xml open.

### 1. Google Search Console (10 min)
1. Go to https://search.google.com/search-console and sign in with a Google account.
2. "Add property" → choose **Domain** → type `aithreat.io` → Continue.
3. Google shows a TXT record (starts with `google-site-verification=`). Copy it.
4. In Netlify: Domains → aithreat.io → DNS settings → "Add new record": type **TXT**, name `@`, value = the text you copied. Save.
5. Back in Search Console click **Verify** (wait a few minutes if it fails the first time).
6. Left menu → **Sitemaps** → enter `sitemap.xml` → Submit.
7. Left menu → **URL inspection** → paste `https://aithreat.io/cases/` → "Request indexing". Do the same for the homepage and two or three case pages. This speeds up the first crawl.
8. Come back in a week: Pages report (what is indexed), Performance report (which queries bring people).

### 2. Bing Webmaster Tools (10 min, and the AI-citation report)
1. Go to https://www.bing.com/webmasters and sign in (Microsoft, Google or Facebook account).
2. Choose "Import from Google Search Console" if offered; it copies the verification and sitemap in one click. Otherwise add `https://aithreat.io` and verify with the DNS option (same TXT-record method as above).
3. Sitemaps → submit `https://aithreat.io/sitemap.xml`.
4. **IndexNow** is already wired into the robot; the key file is `site/8aec11ecd93a48b9b8347867d0af45f6.txt`. To submit every page once: GitHub → Actions → "Update wire every 30 minutes" → Run workflow → tick "Also submit every page in sitemap.xml to IndexNow" → Run.
5. After two to three weeks, open **AI Performance** (or "Search performance" → AI tab) to see which pages Copilot and Bing's AI answers cite. This is the one first-party measurement of AI visibility available today.

### 3. Google Dataset Search (0 min)
Nothing to do: the Dataset structured data on the homepage is picked up automatically once Google crawls it.
Check in a month by searching "AI Threat Watch" at https://datasetsearch.research.google.com.

### 4. Mirror the dataset where researchers and AI assistants already look (20 min)
- **GitHub (public):** create a public repository `aithreat-data` with `incidents.en.json`, the four translation files, a README (what it is, fields, licence, how to cite) and a link to the site. Public GitHub repos are heavily cited by ChatGPT and Perplexity. The robot can be taught to push updates there later.
- **Hugging Face Datasets:** https://huggingface.co/new-dataset → name `aithreat/ai-security-incidents` → upload the same files → licence `cc-by-4.0`. Researchers search there first.
- **Zenodo** (later, quarterly): gives a DOI, which papers need to cite you.

### 5. Analytics you already have
Umami is installed on every page, including the new static ones. Watch "Referrers" for the first newsletter or
news-site link, and "Pages" for which case files pull search traffic. Add the Search Console numbers once a week.

## Choices made today that you can change

- **AI training crawlers are allowed.** robots.txt lets every bot in (search bots and training bots alike). For a reference site that wants to be *the* answer, being in the training data is an asset, and the data is open anyway. If you ever want to block training only, add `User-agent: GPTBot` / `Disallow: /` style blocks for the training agents while keeping the search agents (OAI-SearchBot, PerplexityBot, Claude-SearchBot, Googlebot) allowed.
- **Licence: CC BY 4.0** is stated on every case page and in the Dataset metadata. This matches the research recommendation; change it in `scripts/build_pages.rb` (search for "CC BY") and in `site/index.html` if you decide otherwise.
- **Unverified drafts get no pages.** Only approved case files are published as static pages and in the case RSS. This protects the site's credibility with search engines and with readers.

## The next 30 days, in order

1. Push, then do account steps 1 and 2 (same day).
2. Mirror the dataset on GitHub and Hugging Face (step 4).
3. Trust pages the plan calls for: methodology (inclusion rule, confidence labels, corrections log), named maintainer, contact, `security.txt`. These are what journalists check before citing.
4. Email alerts (even a simple Buttondown or Substack fed by `/cases/feed.xml`) so a launch spike converts into subscribers.
5. Per-company pages (`/cases/company/<name>/`) and a glossary of attack types: the two biggest remaining search-page wins, both generated the same way as today's hubs.
6. Then launch: Show HN mid-week, Product Hunt the following week, newsletter pitches (tl;dr sec, Risky Business, Simon Willison, CyberDaily). The full playbook is in the research artifact.

## How to measure, weekly (15 minutes)

| Where | What to look at | Good sign by day 30 |
| --- | --- | --- |
| Search Console → Pages | Indexed count | Most of the 390 pages indexed |
| Search Console → Performance | Impressions, top queries | Impressions climbing week on week; case titles appearing as queries |
| Bing → AI Performance | Pages cited by AI answers | First citations |
| Umami → Referrers | New domains | First newsletter or news-site referrer |
| Ask ChatGPT, Perplexity and Claude: "Which site tracks AI security incidents?" and "What happened in the DeepSeek database exposure?" | Whether aithreat.io is cited | Cited in at least one of them (repeat weekly; answers vary a lot run to run) |
