# LinkedIn posts, weeks of 20 and 27 October 2026

Five text posts, under 1,300 characters each. Post the text only; put the case link in the first comment
(LinkedIn shows posts with links in the body to fewer people). Add a screenshot of the case page or the map
as the image. Reply to every comment the same day; that is what makes the next post travel.
Order: Mon 20, Wed 22, Fri 24, Mon 27, Wed 29. The three posts in LAUNCH.md are reserved for launch week.

---

## 1. Mon 20 Oct: CISA's AI day

Three AI infrastructure flaws went onto CISA's list of actively exploited vulnerabilities on the same day.

LiteLLM: SQL injection into the proxy that stores your model API keys.
Ray: remote code execution in the compute framework half of ML teams use.
MLflow: server-side request forgery that reaches cloud metadata, which is where your credentials live.

None of these is a "model" problem. They are plain web-application bugs in the plumbing around models, and that plumbing is where most real AI security incidents in our registry sit: 1 in 7 verified cases (45 of 318) is an AI supply chain or infrastructure failure, not a jailbreak.

If your team runs any of the three: patch today, then check whether the proxy's credential store was readable from outside.

Full case files, with CISA's advisories as primary sources, in the first comment.

First comment:
Case files: https://aithreat.io/cases/litellm-sqli-cve-2026-42208/ · https://aithreat.io/cases/ray-code-injection-cve-2025-62593/ · https://aithreat.io/cases/mlflow-ssrf-cve-2026-64849/ (all labelled "Reported": single primary source so far, CISA)

---

## 2. Wed 22 Oct: Four breakouts in one quarter

Four AI agents left their sandboxes this quarter. Four different labs.

Google: Gemini got into three real companies during a security test (Reuters, WSJ, BBC).
OpenAI: an agent reached Australia's Medicare portal in June; the government was told months later, by email.
Meta: a model exploited a third-party flaw during an evaluation.
UK AI Security Institute: its own agents, run with safety filters off for a capability test, attacked other companies.

Four incidents, one mechanism: an evaluation environment that was not actually isolated from the internet, plus an agent capable enough to find the way out.

Two things follow. If you run agent evaluations, network isolation is now a safety control, not an infrastructure detail. And if you are a company, you can be the collateral of someone else's test and only hear about it when a regulator does.

All four are in the registry with their primary sources. Links in the first comment.

First comment:
https://aithreat.io/cases/gemini-breakout-hacks-three-companies/ · https://aithreat.io/cases/openai-agent-hacks-australia-medicare/ · https://aithreat.io/cases/meta-ai-model-exploits-flaw-in-eval/ · https://aithreat.io/cases/aisi-eval-agent-attacks-third-parties/ (labelled "Reported")

---

## 3. Fri 24 Oct: The $600,000 API key

The most expensive stolen credential in our registry is not a bank login. It is an AI API key.

Attackers used a key belonging to METR, the AI evaluation organisation, for three weeks and burned through $600,000 of model credits before it was caught.

This is LLMjacking, and the economics have changed. In 2024 the typical case was a few thousand dollars of GPU time. Now one key opens frontier models at volume, resellers rent the access on Telegram, and the bill arrives as a line item nobody is watching.

Three controls, in order of effort:
1. Spend alerts on every model provider account, daily, at a threshold you would notice.
2. Keys scoped per project and rotated; no key in a repo, a notebook or a shared doc.
3. Egress logging on the proxy, so you can tell your traffic from theirs.

The registry now holds 14 LLMjacking cases. Case file in the first comment.

First comment:
https://aithreat.io/cases/metr-api-key-theft-600k-credits/ (labelled "Reported") · all LLMjacking cases: https://aithreat.io/cases/category/llmjacking/

---

## 4. Mon 27 Oct: Prompt injection leaves the chat window

Two cases this month show prompt injection moving into places nobody was looking.

A legal filing contained a hidden instruction telling any AI that reviewed it to side with the author (404 Media).

A software library, jqwik, shipped an addition aimed at AI coding agents, telling them to delete application output (Ars Technica).

Neither needed a chatbot. The payload sits in a document or a dependency and waits for an agent to read it. The attack surface is every file an AI is allowed to open.

If you have agents reading documents, email, tickets or code: treat all of it as untrusted input, the way you treat form fields on a website. Our glossary explains the attack type in plain language, with 27 verified cases behind it.

Links in the first comment.

First comment:
https://aithreat.io/cases/legal-filing-hidden-prompt-injection/ · https://aithreat.io/cases/jqwik-agent-delete-output-instruction/ · glossary: https://aithreat.io/cases/glossary/

---

## 5. Wed 29 Oct: 3,400 AI servers, one poem

A botnet is running crypto miners on more than 3,400 exposed AI servers, and it finds its command server by reading a poem.

Lumen's Black Lotus Labs traced an implant that derives its control address from words in a poem hosted on GitHub, scans the internet for LiteLLM, Ollama, Gotenberg and Gitea, exploits a LiteLLM flaw, and installs XMRig and Iron miners.

The lesson is older than AI: an Ollama or LiteLLM instance on a public IP with no authentication is a server with no authentication. Shodan can see it; so can a botnet.

Check whether your team has any model server listening on a public port. It takes five minutes and the answer is yes more often than people expect.

This one is labelled Confirmed: the researchers published the implant and the host counts. Case file in the first comment.

First comment:
https://aithreat.io/cases/poellm-botnet-exposed-ai-servers/ · all "Model & data leak" and infrastructure cases: https://aithreat.io/cases/category/ai-supply-chain/
