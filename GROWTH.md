# Growth plan: getting aithreat.io found

Started 14 October 2026, last updated 16 October 2026. Companion to the research synthesis at
https://claude.ai/artifact/2NTWb4bPSWSy6jJsCQPHCG (audiences, 90-day plan) and to `LAUNCH.md`
(paste-ready launch material and the launch calendar). This file is the practical plan: where visits come
from, what is done, what is still yours to do, and how we measure.

## Status at a glance (16 October 2026)

| Area | State |
| --- | --- |
| Site is crawlable | Done. 318 verified case files as static pages in EN/FR/ES/AR/ZH, hubs by type, country and company, glossary, about/method page, 3,496 URLs in the sitemap. The robot rebuilds pages and pings Bing after every 30-minute run. |
| Google Search Console | Done 15 Oct. Domain verified, sitemap submitted, indexing requested for the main pages. Next: read the Pages and Performance reports on 22 Oct. |
| Bing Webmaster Tools | Done 15 Oct. Verified, sitemap submitted, full IndexNow submission run. Next: AI Performance report in early November. |
| Dataset mirrors | Hugging Face done 15 Oct (`karlabouzeid/ai-security-incidents`, linked from the Data page, the about page and the Dataset metadata). GitHub repository is public. Kaggle and Zenodo still open. |
| Email list | Done 15 Oct. Buttondown (`aithreat`), free plan, double opt-in; sign-up box on the homepage and on every generated page. Sending is manual: one digest a week. |
| Analytics | Umami on every page. Read-only dashboard: https://cloud.umami.is/share/dGOwSfE4h8EObblZ. Baseline on 16 Oct: about 50 visitors a day, 5-minute visits, traffic from your own Instagram and Facebook shares only. |
| Content pipeline | 6 drafts waiting for review (53 were reviewed on 15 Oct). Keep the queue empty; every approval becomes five pages within 30 minutes. |
| Launch material | `LAUNCH.md` written and fact-checked: Show HN, Product Hunt, five newsletter pitches, three LinkedIn posts, checklist. Dates: pitches Mon 26 Oct, Show HN Wed 4 Nov, Product Hunt Tue 10 Nov. |
| This week's copy | `newsletters/2026-10-20-digest-01.md` (send Monday 20 Oct) and `social/linkedin-week-of-2026-10-20.md` (five posts, Mon/Wed/Fri). |

## The three questions, answered

**Should I start with Google?**
Yes, Google and Bing together, and both are now done. Google is where journalists, analysts and students
search. Bing matters more than its market share suggests: Microsoft Copilot runs on it, and Bing Webmaster
Tools is currently the only place that shows which of your pages AI answers cite. Do not buy Google Ads: a
free reference site earns nothing per visit, and paid clicks do not build the citations that make a reference.

**Can the site be recommended when people ask ChatGPT, Perplexity, Claude or Gemini?**
Yes, and there is no paid placement for it. AI assistants recommend and cite pages that are (1) crawlable
as plain HTML, (2) indexed by Bing or Google, (3) written as self-contained, quotable answers, and
(4) mentioned on other credible sites. Until 14 October the site failed test 1: one JavaScript page, an empty
shell to a crawler. Tests 1 to 3 are now met; test 4 (mentions elsewhere) is what the seeding list and the
launch are for.

**How do I drive visibility organically?**
Three engines, in order of payoff:
1. **Pages that answer a question.** Done: one page per case in five languages, hubs by type, country and
   company, a glossary. Each new verified case adds five more.
2. **Being cited.** Open data under CC BY 4.0, a permanent link and a ready-made citation on every case,
   mirrors on Hugging Face and GitHub. Still to do: Kaggle, Zenodo DOI, Wikipedia source additions.
3. **Distribution.** People sending people: newsletters, LinkedIn, Hacker News, Product Hunt, Reddit. This
   is where month-one visits come from, and it is the open work below.

## Getting to 1,000 visits: the 30-day traffic plan

**Targets.** Week of 4 November (Show HN week): 1,000+ visits in seven days. End of November: 1,000+ visits
every week without a launch spike. 1,000 a day is a 90-day goal that search and newsletters reach together.

**Where month-one visits come from.** Search takes two to three months to compound. In the first month visits
come from people sending people: a front-page Show HN brings 10,000 to 30,000 visits in 48 hours and a modest
one 1,000 to 3,000; one newsletter mention 500 to 2,000; each LinkedIn post from your own account 50 to 300,
more when a journalist reshares; a well-placed Reddit post 200 to 2,000. Every verified case is a page someone
can link to.

### Weekly rhythm (about 90 minutes of your time a week)

| When | You | Claude |
| --- | --- | --- |
| Monday morning | Paste the digest into Buttondown (Emails, New email), read it once, send. | Draft the digest from the week's verified cases into `newsletters/`. |
| Monday, Wednesday, Friday | One LinkedIn post as text, case link in the first comment. Reply to every comment the same day. | Keep five posts ahead in `social/`. |
| Daily, ten minutes | Review the draft queue on the site (approve or reject by id in `config/approved.txt` / `rejected.txt`). | The robot builds the pages and pings Bing. |
| Friday | Nothing to collect: Claude reads the Umami dashboard and the Search Console numbers you paste. | Report the four numbers (visits, referrers, subscribers, impressions) and adjust next week's posts. |

### Seeding, before the launch (one-off, about two hours, all free)

Each is a durable link from a place people and AI assistants already look. Tick them off here.

1. [x] **GitHub repository public.** Add topics on the repository page (gear icon next to About): `ai-security`, `threat-intelligence`, `dataset`, `prompt-injection`, `deepfake`.
2. [ ] **Awesome lists on GitHub.** Open an issue on each asking to be added (maintainers prefer an issue to a PR from a stranger): `awesome-ml-security`, `awesome-llm-security`, `awesome-threat-intelligence`, `awesome-ai-safety`. One line: "AI Threat Watch (https://aithreat.io): open CC BY dataset and map of verified AI security incidents, updated every 30 minutes."
3. [ ] **Kaggle dataset.** https://www.kaggle.com/datasets, New Dataset, upload the six files from the Desktop folder `huggingface-upload`, licence CC BY 4.0, link to the site in the description.
4. [ ] **Product Hunt "Coming soon" page**, so followers accumulate before 10 November. Use the name, tagline and description from `LAUNCH.md` section 2.
5. [ ] **Reddit, lightly.** One post each on r/cybersecurity and r/artificial: the map link and a plain description ("I built a map of verified AI security incidents; the data is open"). Answer comments, do not repost. r/netsec waits for a methodology write-up.
6. [ ] **Bluesky and Mastodon (infosec.exchange).** Create the accounts, post the same case cards as LinkedIn. Security researchers live there; journalists quote it.
7. [ ] **Wikipedia.** Do not add links to the site. When a case has a Wikipedia article, add the primary sources from the case file to the article; editors find the site on their own.

### Launch (dates and material in `LAUNCH.md`)

- Mon 26 Oct: send the five newsletter pitches (tl;dr sec, Risky Business News, Simon Willison, CyberDaily, AIAAIC Alert).
- Wed 4 Nov, 14:30 Beirut: Show HN, founder comment within a minute, two hours of replies. LinkedIn numbers post the same evening.
- Tue 10 Nov: Product Hunt, maker comment at once, answer every comment.
- Before launch day, every row of the "must be true" checklist in `LAUNCH.md` has to be ticked; move the whole plan by a week rather than launch half-ready.

### After the launch (weeks of 9 and 16 November)

- Turn every request from the HN and PH threads into a GitHub issue, ship two within a week, and post the "you asked, we built it" update in the same threads.
- Send the quarterly-numbers post to the five editors as a one-line follow-up with a chart.
- Pitch one mainstream desk (Reuters Technology, FT Alphaville, Bloomberg Cyber) with the "AI agents breaking out of evaluations" pattern: four cases, four vendors, one quarter. Mainstream press, not tech press, produced Have I Been Pwned's biggest days.

## Still open on the accounts side

- **Buttondown paid plan (your call, about $9 a month):** unlocks RSS-to-email (a per-case or weekly email sent automatically from `https://aithreat.io/cases/feed.xml`) and a custom welcome email. Until then the Monday digest is manual.
- **Kaggle and Zenodo** (see seeding list; Zenodo quarterly, it gives a DOI that papers need).
- **Hosting moved to GitHub Pages on 15 Oct.** Netlify skipped deploys when the robot exceeded its credit budget, so aithreat.io is now served from GitHub Pages (the robot publishes after every run). The DNS records, including the Search Console TXT record, still live in Netlify DNS; do not delete the Netlify account.
- **Google Dataset Search:** nothing to do; check in a month at https://datasetsearch.research.google.com by searching "AI Threat Watch".

## What is in place (reference)

| Piece | What it does |
| --- | --- |
| `scripts/build_pages.rb` | Generates every static page: cases, hubs by type, country and company, glossary, about, redirects for merged cases, per-language RSS, `sitemap.xml`, `llms.txt`, the sign-up box. Deterministic, run by the robot after every wire update. |
| `scripts/indexnow.rb` | Tells Bing (and Yandex, Seznam, Naver) which pages changed. Key file `site/8aec11ecd93a48b9b8347867d0af45f6.txt`. A manual workflow run with the "submit every page" box resubmits the whole sitemap. |
| `robots.txt` | Welcomes all crawlers, including AI search and training bots; hides the raw wire JSON. |
| JSON-LD | Article and breadcrumbs on each case; WebSite, Organization and Dataset (with the Hugging Face mirror as `sameAs`) on the homepage; CollectionPage on hubs; AboutPage on `/about/`. |
| Open Graph and Twitter cards | Brand image `assets/brand/og-image.png`; links unfurl on LinkedIn, Slack and X. |
| Feeds | `/cases/feed.xml` per language (verified cases), `/feed.xml` (wire), `/feeds/` (critical, threats, drafts, per category, per country). |
| CORS on `/data/*` | Notebooks and other sites can load the JSON directly. |
| 404 page | Sends people to the case list instead of a hosting error. |

## Choices made that you can change

- **AI training crawlers are allowed.** For a reference site that wants to be the answer, being in the training data is an asset, and the data is open anyway. To block training only, add `User-agent: GPTBot` / `Disallow: /` style blocks for the training agents while keeping the search agents (OAI-SearchBot, PerplexityBot, Claude-SearchBot, Googlebot) allowed.
- **Licence: CC BY 4.0** on every page and in the Dataset metadata. Change it in `scripts/build_pages.rb` (search for "CC BY") and in `site/index.html`.
- **Unverified drafts get no pages** and no feed entry until approved. This protects credibility with search engines and readers.

## How to measure, weekly

| Where | What to look at | Baseline 16 Oct | Good sign by 15 Nov |
| --- | --- | --- | --- |
| Umami dashboard | Visitors and visits per week, referrers | ~50 visitors/day, referrers: Instagram, Facebook | 1,000+ visits in launch week; newsletter and news-site referrers |
| Search Console, Pages | Indexed count | not yet reported | Most of the 3,496 URLs indexed |
| Search Console, Performance | Impressions, top queries | 0 | Climbing week on week; case titles appearing as queries |
| Bing, AI Performance | Pages cited by AI answers | 0 | First citations |
| Buttondown | Confirmed subscribers | 0 | 100+ after launch week |
| Ask ChatGPT, Perplexity and Claude: "Which site tracks AI security incidents?" | Whether aithreat.io is cited | not cited | Cited in at least one (repeat weekly; answers vary) |

Weekly log (Claude fills this in on Fridays):

| Week ending | Visitors | Visits | Top referrers | Subscribers | Search impressions | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 17 Oct | | | | | | first digest and posts go out on 20 Oct |
