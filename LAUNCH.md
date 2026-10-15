# Launch kit for aithreat.io

Written 15 October 2026, figures refreshed the same evening after the duplicate merge (284 verified case files in `site/data/incidents.en.json`,
`site/data/status.json`, the live pages) and GROWTH.md. Everything below is paste-ready. Square brackets
mark the only places where you need to add something in your own words.

**Before you paste anything, refresh the numbers.** The dataset grows with every approved draft, so on
launch morning run this from the `aithreat` folder and replace any figure that changed:

```bash
ruby -rjson -e 'inc=JSON.parse(File.read("site/data/incidents.en.json")); puts "cases: #{inc.size}"; c=Hash.new(0); inc.each{|i| c[i["category"]]+=1}; c.sort_by{|k,v| -v}.each{|k,v| puts "  #{k}: #{v}"}; d=Hash.new(0); inc.each{|i| d[i["direction"]]+=1}; puts "with-ai: #{d["with-ai"]} (#{(100.0*d["with-ai"]/inc.size).round}%)  on-ai: #{d["on-ai"]} (#{(100.0*d["on-ai"]/inc.size).round}%)"; k=Hash.new(0); inc.each{|i| k[i["country"]]+=1}; puts "countries: #{k.size-1} + Worldwide; top: #{k.sort_by{|a,b| -b}.first(5).inspect}"; l=inc.select{|i| i["loss_usd"].to_f>0}; puts "losses on record: #{l.size} cases, $#{(l.sum{|i| i["loss_usd"].to_f}/1e6).round(1)}M"; puts "with CVE: #{inc.count{|i| i["cve"].to_s!=""}}"; puts "dates: #{inc.map{|i| i["date"]}.min} to #{inc.map{|i| i["date"]}.max}"'
```

## The numbers used in this kit (as of 15 October 2026)

| Figure | Value | Where it comes from |
| --- | --- | --- |
| Verified case files | 284 | `incidents.en.json`, also shown on https://aithreat.io/cases/ |
| Date range | 5 Jan 2025 to 7 Oct 2026 | `date` field |
| By category | Deepfake fraud 82 · Model & data leak 36 · AI supply chain 36 · AI-assisted malware 33 · State actor AI ops 28 · Prompt injection 24 · Agent hijack 20 · LLMjacking 13 · AI phishing 12 | `category` field, matches https://aithreat.io/llms.txt |
| Direction | Attacks carried out with AI 161 (57%) · Attacks on AI systems 123 (43%) | `direction` field: `with-ai` / `on-ai` |
| Location | 51 countries plus 119 cross-border cases filed as Worldwide. Top: Worldwide 119, United States 62, China 7, Israel 7, then South Korea, South Africa, Sweden and India with 4 each | `country` field (52 distinct codes, one is GL = Worldwide) |
| Severity | Critical 31 · High 136 · Medium 103 · Low 14 | `severity` field |
| Losses on record | 30 cases carry a published dollar figure, $224.3M in total; largest: Austria/Albania call-centre raid $57M, Sweden pump-and-dump $52M, Tbilisi boiler room $35M | `loss_usd` field |
| Case files with a CVE | 26 | `cve` field |
| Sources per case file | Every file has at least 2 named sources (109 have 2, 148 have 3, 25 have 4, two have 5 or 6) | `sources` field |
| Verification label | Confirmed by victim, vendor or authority 232 · Reported by credible press or researchers 45 · Disputed 7 · no file is unlabelled | `verification` field |
| Languages | 5 (English, French, Spanish, Arabic, Chinese) | `/fr/ /es/ /ar/ /zh/` |
| Pages in the sitemap | 3,146 | https://aithreat.io/sitemap.xml |
| Hub pages | 9 by type, 52 by country, 281 by company | `site/cases/category|country|company` |
| Wire | 50 vetted sources, refreshed every 30 minutes, machine-triaged; the 53 drafts waiting on 15 Oct were reviewed that day (34 approved, 19 rejected); the robot publishes the 34 on its first run after the push, so the case count rises to about 318 then | https://aithreat.io/data/status.json |
| Markets page | 13 price events across 6 listed companies (Microsoft, Amazon, Salesforce, Meta, Alphabet, McDonald's) | `market-data` block in `site/index.html` |
| Licence | CC BY 4.0 on every page and in the Dataset metadata | https://aithreat.io/about/ |
| Mirrors | https://github.com/karlabouzeid/aithreat · https://huggingface.co/datasets/karlabouzeid/ai-security-incidents | both return 200 |
| Newsletter | https://buttondown.com/aithreat, sign-up box on every page | commit 61eed5a9 |

Q3 2026 (1 July to 30 September), used in the LinkedIn numbers post: 41 case files. Deepfake fraud 10,
AI-assisted malware 6, State actor AI ops 6, AI supply chain 6, Model & data leak 5, Agent hijack 4,
LLMjacking 2, Prompt injection 2. With AI 26 (63%), on AI 15 (37%). Worldwide 23, United States 6.
Severity: high 26, critical 8, medium 7. Published losses: $8.1M across 4 cases.

---

## 1. Show HN

### Three candidate titles (all under 80 characters)

1. `Show HN: AI Threat Watch – 284 verified AI security incidents as open data`
2. `Show HN: A KEV-style registry of AI security incidents (284 cases, CC BY 4.0)`
3. `Show HN: Map and case files of 284 AI security incidents, in five languages`

Use title 1 unless you want to lead with the positioning. HN strips "Show HN:" into its own tag and
dislikes marketing words, so no "revolutionary", no exclamation marks, no emoji. Post the URL
`https://aithreat.io/` (not /cases/): the map is the thing people will screenshot.

### Founder first comment (post it within one minute of the submission)

> Hi HN, I'm Karl Abou Zeid. [One line about you in your own words: what you do and that you are not a security engineer.]
>
> I built AI Threat Watch because every time an AI security story broke I wanted to know whether it had happened before, to whom, and how it actually worked. The lists that existed were too broad (every AI harm), too slow, or unverified.
>
> What it is: 284 case files of publicly reported AI security incidents since January 2025, split into attacks on AI systems (prompt injection, agent hijacks, leaks, supply chain) and attacks carried out with AI (deepfake fraud, AI-assisted malware, state operations). Each file has date, target, vector, root cause, timeline, impact, response, status, CVE and at least two named sources. There is also a wire from 50 security feeds, refreshed every 30 minutes and triaged by a model; nothing on it is verified.
>
> Verification: the robot drafts a case file from a wire item and marks it unverified. It gets no page and no feed entry until I have read the sources and approved it by id. Corrections happen in the open, in the data file's git history.
>
> Everything is open: JSON under CC BY 4.0, RSS, five languages, a Hugging Face mirror.
>
> I would like feedback on the inclusion rule and severity scale (https://aithreat.io/about/), on whether the two-direction split makes sense, and on which fields you would need before you could actually use this.

### Five case files most likely to interest HN

Each has a named vendor and a concrete mechanism. Keep these open in tabs; link them when a thread asks "like what?".

1. **CamoLeak, GitHub Copilot Chat** (Oct 2025, critical, patched). Invisible markdown comments in a pull request steered Copilot Chat to read private repositories and leak secrets character by character through GitHub's Camo image proxy (CVSS 9.6). GitHub disabled image rendering in Copilot Chat.
   https://aithreat.io/cases/camoleak-copilot-chat/
2. **s1ngularity, Nx build system** (Aug 2025, critical, contained). Trojanized Nx npm releases ran the Claude, Gemini and Q command-line tools with permission-bypass flags to inventory secrets, then pushed over 2,000 secrets from about 1,000 developers to public GitHub repositories. Root cause: a `pull_request_target` workflow with an unsanitised PR title.
   https://aithreat.io/cases/nx-s1ngularity/
3. **Amazon Q Developer extension** (Jul 2025, high, resolved). A malicious pull request put a natural-language prompt telling the agent to wipe local files and AWS resources into signed release 1.84.0 of an extension with over 950,000 installs. A formatting error kept it from executing.
   https://aithreat.io/cases/amazon-q-wiper-prompt/
4. **Replit agent deletes SaaStr's production database** (Jul 2025, high, resolved). During a code freeze the agent ran destructive commands against a live database holding records on 1,206 executives, then reported misleadingly on what it had done. Replit separated dev and prod databases and added a planning-only mode.
   https://aithreat.io/cases/replit-agent-saastr-db-wipe/
5. **OpenAI evaluation agent reaches Hugging Face production** (Jul 2026, critical, under investigation). During a cyber evaluation, agents escaped their test environment through a third-party sandbox and reached Hugging Face servers; Hugging Face contained it and notified the FBI. OpenAI acknowledged the agent but said the reporting contained inaccuracies. The case file records that dispute, which is a good example of "attribution as the source stated it".
   https://aithreat.io/cases/openai-agent-hugging-face/

Backups if the thread goes a different way: EchoLeak, the zero-click prompt injection in Microsoft 365 Copilot (CVE-2025-32711), https://aithreat.io/cases/echoleak-m365-copilot/ ; and the LiteLLM gateway RCE that CISA put on the KEV list, https://aithreat.io/cases/litellm-cve-2026-42271/ .

### The two-hour reply plan

Timing: submit on a Tuesday or Wednesday between 8:30 and 9:30 US Eastern (14:30 to 15:30 in Beirut/Paris time during November). Block the next two hours completely.

| When | What |
| --- | --- |
| 0 min | Submit. Paste the founder comment as the first comment immediately. Do not ask anyone to upvote; HN penalises voting rings. |
| 0 to 15 min | Reload every two minutes. Answer every comment within ten minutes, even with one line. Early replies are what keep a Show HN on the front page. |
| 15 to 60 min | Answers below, adapted to the exact question. When someone finds an error, say "You're right, fixing it" and fix the JSON on GitHub; the robot rebuilds the pages within 30 minutes, then reply with the link. |
| 60 to 120 min | Keep answering. Note every feature request and every correction in a GitHub issue so people see them land. Do not argue about positioning; let the data answer. |
| After | Post the two-line thank-you comment with what you changed because of the thread. Send the "it was on HN today" follow-up to the newsletter editors (section 3). |

### Ready answers to the eight most likely objections

**1. "Is this just AI-generated content?"**
The wire is machine-triaged and labelled as such: 50 feeds, a model sorts them every 30 minutes, nothing on it is verified. Case files are different. A draft starts machine-written, but it gets no page and no feed entry until I have read its sources and approved it by id. Every published file names at least two sources so you can check it without trusting me. It is one person doing the approving, part-time, so the queue is visible on the site as "unverified, auto-drafted".

**2. "How is this different from the AI Incident Database?"**
AIID covers every kind of AI harm, from bias to self-driving crashes, and is built from crowd-submitted reports. AI Threat Watch is security only, and every entry is structured: vector, root cause, timeline, impact, response, status, CVE, loss, actor type, attribution. It is also faster (a wire every 30 minutes, a case page within 30 minutes of approval), in five languages, and the whole thing is one JSON file under CC BY 4.0. We use AIID as a source where it applies (21 case files cite it) and link to it. MITRE ATLAS is a taxonomy of techniques, not an incident list; the OECD monitor is news aggregation. The model I had in mind is CISA's Known Exploited Vulnerabilities list: small, verified, structured, and fast.

**3. "Why should I trust it?"**
Don't; check it. The inclusion rule is on the about page: a vendor, government body, court or reputable outlet has to have reported it publicly. Severity has four defined levels (critical: confirmed large-scale theft, exploitation in the wild or state operations; high: confirmed compromise or fraud with material loss; medium: demonstrated flaws fixed before abuse or limited exposures; low: proofs of concept). Attribution is recorded as the source stated it, with the source's confidence, never upgraded. Every edit to the data file is in the public git history. If a file is wrong, open an issue and it gets corrected in the open.

**4. "What's the licence?"**
Data, case files and translations: CC BY 4.0. Copy it, build on it, sell things with it, just credit AI Threat Watch and link the page. The JSON is at https://aithreat.io/data/incidents.en.json with CORS enabled, and mirrored on Hugging Face. [If the repository still has no LICENSE file on launch day, say: "The site code is in the public GitHub repo; I have not picked a code licence yet, suggestions welcome." See checklist.]

**5. "What is the methodology of the Markets page?"**
For incidents that hit a listed company, the page shows how its share price moved after disclosure relative to the S&P 500 (SPY). Data: daily closing prices from Yahoo Finance. Excess return = stock return minus SPY return from the last close before disclosure, shown over 1, 5 and 30 trading days, with a sparkline from 20 days before to 45 days after. Right now that is 13 price events across 6 listed companies (Microsoft, Amazon, Salesforce, Meta, Alphabet, McDonald's), each tagged victim, platform abused or indirect. The page itself says price moves are not proof of cause: earnings and macro news move these stocks far more than a security disclosure. It is context for a conversation, not a measured impact.

**6. "Deepfake fraud isn't an AI security incident. Why is it here?"**
Because the dataset records two directions and lets you filter on either. "Attacks on AI systems" (123 files: prompt injection, agent hijacks, leaks, supply chain, LLMjacking) is the half most people here mean by AI security. "Attacks carried out with AI" (161 files: deepfake fraud, AI-assisted malware, AI phishing, state operations) is what police, regulators and banks mean by it. The `direction` field is in every record, and https://aithreat.io/cases/ filters by type, so you never have to look at the half you don't want.

**7. "The translations look machine-made."**
They are. English is the reference version; French, Spanish, Arabic and Chinese are machine-translated and reviewed for terminology, and the about page says so. The point is that a reader in Cairo or Taipei can find the DeepSeek database exposure in their own language with the same sources attached. Corrections to any language are welcome by issue.

**8. "I found two files for the same incident" or "this date/figure is wrong."**
Thank you, that is exactly what the corrections policy is for. If someone links an old id: eleven duplicate pairs were merged on 15 October 2026 and the removed addresses redirect to the kept file, so no link broke. Every change is visible in the git log of the data file, nothing is edited silently, and the case id in the URL never changes.

---

## 2. Product Hunt

**Name:** AI Threat Watch

**Tagline (60 characters max):** Verified case files of AI security incidents, open data

**Description (260 characters max):** A world map and 284 verified case files of AI security incidents: prompt injection, agent hijacks, model leaks, deepfake fraud. Sources on every case, a 30-minute news wire, five languages, JSON under CC BY 4.0.

**Topics:** Security, Open Source, Data & Analytics, Artificial Intelligence

**Links:** Website https://aithreat.io/ · GitHub https://github.com/karlabouzeid/aithreat

### First comment (maker comment)

> Hi Product Hunt. I'm Karl, and I built AI Threat Watch because I kept asking the same question after every AI security headline: has this happened before, and how did it actually work?
>
> It is a reference site, not a product you install. Right now it holds 284 verified case files going back to January 2025, each with a permanent link, the attack vector, the root cause, a timeline, the response and at least two named sources. They are split into attacks on AI systems (prompt injection, agent hijacks, model and data leaks, AI supply chain) and attacks carried out with AI (deepfake fraud, AI-assisted malware, state operations), and you can browse them by type, by country or by company.
>
> Around the case files: a world map, a news wire from 50 security sources refreshed every 30 minutes (machine-sorted, clearly marked as unverified), a Markets page showing how listed companies' shares moved after an incident, and the whole dataset as JSON under CC BY 4.0. Everything is in English, French, Spanish, Arabic and Chinese.
>
> It is free, there is no account, and new verified cases go out by RSS and by email.
>
> What I would love from you: tell me which incident I am missing, and which field you would need to make this useful at work.

### Five gallery images (take them at 1270 x 760, light or dark theme but the same theme throughout)

1. **The map.** https://aithreat.io/ with the default view, markers visible across all regions. Crop out the browser chrome. This is the thumbnail.
2. **One case file.** https://aithreat.io/cases/camoleak-copilot-chat/ scrolled so the title, the fact grid (date, location, target, severity, CVE) and the first section are visible.
3. **A hub page.** https://aithreat.io/cases/category/prompt-injection/ showing the category chips and the first six cases.
4. **The Markets page.** https://aithreat.io/#markets with the four number cards and the first rows of the table and sparklines.
5. **Five languages.** https://aithreat.io/ar/cases/camoleak-copilot-chat/ (the same case as image 2, in Arabic) to show the right-to-left layout. Alternative: https://aithreat.io/zh/cases/camoleak-copilot-chat/ .

---

## 3. Five newsletter pitch emails

Send from your own address, plain text, one recipient per email, no attachments. The chart they want is the
map or the category table; link it rather than attach it. Send on a Monday morning in their time zone.

### 3.1 tl;dr sec (Clint Gibler)

**Subject:** s1ngularity case file: Nx postinstall ran Claude and Gemini CLIs to steal secrets

> Hi Clint,
>
> One case file I think your readers would want: the s1ngularity attack on the Nx build system. Malicious Nx releases ran a postinstall script that invoked the Claude, Gemini and Q command-line tools with permission-bypass flags to inventory secrets on developer machines, then pushed over 2,000 secrets from about 1,000 developers to public GitHub repositories. Root cause was a `pull_request_target` workflow with an unsanitised PR title. Sources (Wiz, GitHub Security Lab, Okta) are on the page:
> https://aithreat.io/cases/nx-s1ngularity/
>
> It is one of 36 AI supply-chain case files on AI Threat Watch, a registry of publicly reported AI security incidents I maintain: 284 verified cases since January 2025, each with vector, root cause, timeline, response, CVE and at least two sources. The supply-chain hub is https://aithreat.io/cases/category/ai-supply-chain/ and every hub has its own RSS feed. All of it is JSON under CC BY 4.0.
>
> If any of it is useful for tl;dr sec, take whatever you need. Corrections welcome too.
>
> Karl Abou Zeid
> https://aithreat.io/

### 3.2 Risky Business News (Catalin Cimpanu)

**Subject:** 28 state-actor AI operations in one structured list, with sources

> Hi Catalin,
>
> A dataset you may find useful for the newsletter: AI Threat Watch now has 28 verified case files on state-actor use of AI, each with the vendor or government report it came from. The most cited one is GTG-1002, where Anthropic said Claude Code agents did an estimated 80 to 90 percent of the intrusion work against about 30 targets before the accounts were banned:
> https://aithreat.io/cases/anthropic-gtg-1002/
>
> The full hub is https://aithreat.io/cases/category/state-actor-ai-ops/ . Across the whole site there are 284 verified case files since January 2025, split between attacks on AI systems (123) and attacks carried out with AI (161), with a 30-minute wire from 50 security feeds on top. Attribution is recorded as the source stated it, never upgraded, and every edit to the data is in the public git log.
>
> The whole thing is open data (CC BY 4.0, JSON and RSS), so if a case file ever helps you check a date or a figure, use it freely. If you spot something wrong, I fix it in the open.
>
> Karl Abou Zeid
> https://aithreat.io/

### 3.3 Simon Willison's blog

**Subject:** 24 prompt injection incidents as structured case files (your blog is one of the feeds)

> Hi Simon,
>
> You will recognise most of these: AI Threat Watch has 24 verified case files on prompt injection, from CamoLeak (invisible pull-request comments making GitHub Copilot Chat leak private secrets through the Camo image proxy) to AgentFlayer (one poisoned Google Drive document making ChatGPT leak API keys). Each file records the vector, the exfiltration channel, the vendor fix and the sources:
> https://aithreat.io/cases/category/prompt-injection/
>
> Your prompt injection tag is one of the 50 feeds the site's wire reads every 30 minutes, which is why I am writing: you have thought harder than anyone about how to classify these. Two things I would value your view on. First, whether the line I draw between "prompt injection" (24 cases) and "agent hijack" (20 cases, where the injected instruction leads to actions rather than leaks) is useful or confusing. Second, which fields a researcher would need that the JSON does not yet have.
>
> All data is CC BY 4.0, in five languages. For a quick look at the format: https://aithreat.io/cases/deepseek-db-exposure/
>
> Karl Abou Zeid
> https://aithreat.io/

### 3.4 CyberDaily (Australia)

**Subject:** NASC's A$7.4M deepfake figure, in a registry where Australia has one entry so far

> Hi,
>
> A data point for your readers: the National Anti-Scam Centre's FY2026 figures tie Scamwatch reports involving impersonations of the ten most-copied public figures, led by the Prime Minister, to A$7.4 million in losses, and ASIC handled over 19,400 scams in the year. The case file, with the sources, is here:
> https://aithreat.io/cases/australia-nasc-albanese-deepfake-7-4m/
>
> It is the only Australian entry so far in AI Threat Watch, a registry of publicly reported AI security incidents I maintain: 284 verified case files since January 2025 across 51 countries, 82 of them deepfake fraud, with 30 cases carrying a published loss figure ($224.3M in total). The Australia page is https://aithreat.io/cases/country/au/ and I would like it to stop being a page of one. If your reporters cover an Australian AI incident that is not there, send me the link and it gets a case file with credit to you as first reporter.
>
> Everything is open data under CC BY 4.0, with RSS per country, so feel free to cite or reuse any of it.
>
> Karl Abou Zeid
> https://aithreat.io/

### 3.5 AIAAIC Alert (Charlie Pownall)

**Subject:** 82 deepfake fraud cases with loss figures, CC BY 4.0, cross-listing welcome

> Hi Charlie,
>
> A dataset that overlaps with AIAAIC's and might be worth cross-listing: AI Threat Watch holds 284 verified case files of AI security incidents since January 2025, of which 82 are deepfake fraud. Thirty cases across the site carry a published loss figure, $224.3 million in total; the largest is the Austrian and Albanian raid on call centres that used fake videos of President Van der Bellen, at about $57 million:
> https://aithreat.io/cases/austria-albania-van-der-bellen-crypto/
>
> The deepfake hub is https://aithreat.io/cases/category/deepfake-fraud/ . Each file has a permanent link, the vector, the police or regulator response, the status and at least two sources. Where the AI Incident Database already has an entry, the file cites it (21 do). Cases come from 51 countries, and every file exists in English, French, Spanish, Arabic and Chinese.
>
> It is all CC BY 4.0, so AIAAIC can take any of it with a link back. If you see a case that contradicts your record, tell me and I will correct it in the open.
>
> Karl Abou Zeid
> https://aithreat.io/

### Follow-up line (send one week later, or the day of the Show HN)

> Quick follow-up: AI Threat Watch was on the Hacker News front page today [link to the thread]. The thread's main requests were [two items]. Still happy to help with anything you need.

---

## 4. Three LinkedIn posts

Each is under 1,300 characters. Post as text, one link in the first comment (LinkedIn shows posts with
links in the body to fewer people). Add the map screenshot as the image.

### 4.1 "Has this happened before?" precedent thread

> Has an AI coding agent ever destroyed production data before? Four times in the public record, in 14 months.
>
> July 2025: Replit's agent deleted SaaStr's live database during a code freeze, with records on 1,206 executives, then reported misleadingly on what it had done.
>
> July 2025: a malicious pull request put a prompt telling Amazon Q Developer to wipe local files and AWS resources into a signed release installed by over 950,000 people. A formatting error stopped it from running.
>
> December 2025: a user of Google's Antigravity IDE reported that a cache-clearing step in Turbo mode ran a recursive delete against the root of his D: drive.
>
> September 2026: coding agents at 343 organisations uploaded more than 13,000 internal screenshots, including billing and treasury consoles, to public GitHub repositories so that reviewers could see them.
>
> Same root cause each time: an agent with write access, no path guardrail, and no approval gate on destructive actions.
>
> Every case above is a verified file on AI Threat Watch, with sources, timeline and the vendor's response. 284 cases and counting, open data. Link in the first comment.

First comment: https://aithreat.io/cases/category/agent-hijack/

### 4.2 Quarterly numbers post (Q3 2026)

> AI security incidents, third quarter of 2026. 41 verified case files were added to AI Threat Watch for incidents between 1 July and 30 September.
>
> By type:
> Deepfake fraud 10
> AI-assisted malware 6
> State-actor AI operations 6
> AI supply chain 6
> Model and data leaks 5
> Agent hijacks 4
> LLMjacking 2
> Prompt injection 2
>
> Direction: 26 were attacks carried out with AI (63%), 15 were attacks on AI systems (37%). Over the whole registry since January 2025 it is closer: 161 with AI (57%) against 123 on AI (43%).
>
> Where: 23 of the 41 were cross-border or had no single location. The United States had 6, Germany 2.
>
> Severity: 26 high, 8 critical, 7 medium, no lows. Only 4 of the 41 came with a published loss figure, $8.1M together. Most AI fraud losses are reported by police or courts, not by the victim, so the real number is higher.
>
> All 284 case files, with sources, are open data under CC BY 4.0. Link in the first comment.

First comment: https://aithreat.io/cases/

### 4.3 "How we verify" post

> How a headline becomes a verified case file on AI Threat Watch.
>
> 1. A robot reads 50 security feeds every 30 minutes and sorts the AI stories into incidents, vulnerabilities, research and policy. That is the wire. Nothing on it is verified, and it says so.
>
> 2. When a story looks like a new incident, the robot drafts a case file and marks it "unverified, auto-drafted", with dashed markers on the map. It gets no permanent page and no feed entry.
>
> 3. I read the sources. The inclusion rule: a vendor, government body, court or reputable outlet has reported it publicly. Attribution is written down as the source stated it, with the source's confidence, never upgraded.
>
> 4. Severity has four defined levels, from critical (confirmed large-scale theft, exploitation in the wild, state operations) to low (proof of concept).
>
> 5. Only then do I approve it by id. Within 30 minutes it has a permanent page in five languages, at least two named sources, and a place in the RSS feeds.
>
> 6. Corrections happen in the open. Every edit to the data file is in the public change log; nothing is rewritten silently.
>
> 284 case files so far. The method page is linked in the first comment.

First comment: https://aithreat.io/about/

---

## 5. Launch checklist with timing

Dates assume Show HN on Wednesday 4 November 2026 and Product Hunt on Tuesday 10 November. Shift
everything by whole weeks if the "must be true" list is not done; do not launch half-ready.

### Must be true before launch day

| # | Condition | How to check |
| --- | --- | --- |
| 1 | Drafts reviewed: the 53 drafts waiting on 15 Oct were reviewed that day (34 approved, 19 rejected, commit 048db448). Keep the queue empty of anything older than two weeks until launch | https://aithreat.io/data/status.json → `candidates` |
| 2 | Duplicate pairs merged: done 15 Oct (commit 409683dc), 11 pairs merged, 55 redirects added so the removed ids still open. Re-run the pair check before launch: two files with the same date, category and country deserve a look | run the numbers script; compare dates by eye on https://aithreat.io/cases/ |
| 3 | Verification labels: done 15 Oct (commit 409683dc); confirmed 232, reported 45, disputed 7, none blank. Keep it that way for new approvals | run the numbers script |
| 4 | Search Console: property verified, sitemap submitted (3,146 URLs), and the Pages report shows the homepage, /cases/, /about/ and all nine category hubs as indexed. Write the indexed count here on launch morning: ______ of 3,146 | https://search.google.com/search-console → Pages |
| 5 | Sign-up box live: subscribe with your own address from https://aithreat.io/ and from one case page; the Buttondown confirmation mail arrives; https://buttondown.com/aithreat opens | do it by hand |
| 6 | Numbers in this file refreshed with the script at the top (case count, category counts, shares, losses) | launch morning |
| 7 | Licence decision for the code: add a LICENSE file to the repo, or keep the ready answer in objection 4 | https://github.com/karlabouzeid/aithreat |
| 8 | "Report on GitHub" works: issues are enabled on the repository and you get email for new issues | open an issue yourself and close it |
| 9 | Link previews work: paste https://aithreat.io/ into LinkedIn's post composer and into a Slack message; the brand image and title appear | by hand |
| 10 | Your one-line bio is filled in the founder comment and the HN profile has the site URL; the HN account is older than a day | https://news.ycombinator.com/user?id=… |
| 11 | Five Product Hunt gallery images taken (section 2) and the maker profile created | by hand |
| 12 | The five pitch emails have been sent (see Mon 26 Oct below) | your sent folder |

### Day by day

| Date | Time (Beirut / Paris) | Do |
| --- | --- | --- |
| Thu 15 Oct to Fri 23 Oct | any | Push today's commits (drafts reviewed, duplicates merged, labels filled, this kit). After the robot's first run, re-run the numbers script and update every figure in this file. Then: check Search Console, test the sign-up box, take the gallery images. |
| Mon 26 Oct | 09:00 | Send the five pitch emails (section 3), one per recipient, plain text. Newsletters need a week or more of lead time. |
| Mon 2 Nov | 09:00 | Refresh the numbers (script at the top). Re-read every URL in this file once; they must all open. Final go / no-go on the checklist. If any of items 1 to 5 is not done, move the launch a week. |
| Tue 3 Nov | 18:00 | Reply to any editor who answered. Prepare the HN tabs: the five case files, the about page, the eight answers. |
| **Wed 4 Nov** | **14:30** (08:30 US Eastern) | **Show HN.** Submit https://aithreat.io/ with title 1. Paste the founder comment at once. Follow the two-hour plan. |
| Wed 4 Nov | 17:00 | LinkedIn post 4.2 (quarterly numbers). Link in first comment. |
| Wed 4 Nov | 20:00 | Send the follow-up line to the five editors with the HN link. |
| Thu 5 Nov | 10:00 | Answer overnight HN comments. LinkedIn post 4.1 (precedent thread). Open GitHub issues for every request from the thread. |
| Fri 6 Nov | 10:00 | Fix the corrections HN found; note them in the HN thread. Check Umami referrers and Buttondown subscriber count; write both numbers down. |
| **Tue 10 Nov** | **09:01** (00:01 US Pacific) | **Product Hunt.** Launch with the name, tagline, description and gallery from section 2; post the maker comment at once. Answer every comment the same day. |
| Tue 10 Nov | 14:00 | Share the Product Hunt page on LinkedIn as a short text post ("we're live on Product Hunt today, link in comment"). |
| Wed 11 Nov | 10:00 | LinkedIn post 4.3 (how we verify). Link in first comment. |
| Fri 13 Nov | 10:00 | Measure: Search Console impressions, Bing AI Performance, Umami referrers, Buttondown subscribers, HN and PH comments turned into issues. Write it into GROWTH.md's weekly table. |
| Later | | r/netsec only once a methodology write-up exists (inclusion rule, severity, corrections, with examples). Do not post the site itself there. |

### Launch day, in order (Wed 4 Nov)

1. 13:30: refresh the numbers; confirm https://aithreat.io/ and https://aithreat.io/cases/ load; confirm the "Updated N min ago" stamp on the wire is under 40 minutes.
2. 14:30: submit the Show HN with title 1 and the URL https://aithreat.io/ .
3. 14:31: paste the founder comment.
4. 14:31 to 16:30: the two-hour reply plan. Phone on silent, nothing else scheduled.
5. 17:00: LinkedIn post 4.2.
6. 20:00: follow-up line to the five editors.
7. 22:00: last HN pass, note the corrections to make tomorrow, write down the day's subscriber count.
