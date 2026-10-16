#!/usr/bin/env ruby
# frozen_string_literal: true
# Once a day: finds new Reddit threads that one of our case files answers, drafts a reply for each,
# and sends the best few to Karl privately on Telegram. Nothing is ever posted to Reddit: he reads,
# edits and posts the replies himself. Automated posting would get aithreat.io banned site-wide.
#
# Source: each subreddit's public /new.rss (the JSON API needs approval). Matching is local:
# a thread matches a case when it names something specific to it (a CVE, an actor code, a rare
# product or campaign name) or a topic we have a hub page for (prompt injection, LLMjacking...).
# State: config/reddit_watch.json (last run date, threads already sent).
#
# Secrets: TELEGRAM_BOT_TOKEN (the channel bot), TELEGRAM_ALERT_CHAT_ID (Karl's own chat id, from
#          @userinfobot; he must have pressed Start in a chat with the bot), ANTHROPIC_API_KEY (drafts;
#          without it a plain template is used).
#
# Usage: ruby scripts/reddit_watch.rb             # runs once per UTC day, from 05:00 UTC
#        ruby scripts/reddit_watch.rb --force     # run now regardless of the date
#        ruby scripts/reddit_watch.rb --dry-run   # print what would be sent; send and save nothing

require "json"
require "net/http"
require "uri"
require "cgi"
require "time"
require "set"

ROOT = File.expand_path("..", __dir__)
CASES = File.join(ROOT, "site", "data", "incidents.en.json")
STATE = File.join(ROOT, "config", "reddit_watch.json")
BASE = "https://aithreat.io"
MODEL = ENV.fetch("ATW_MODEL", "claude-sonnet-5-5")
UA = "aithreat-alerts/1.0 (daily reading list for the site owner; https://aithreat.io)"
DRY_RUN = ARGV.include?("--dry-run")
FORCE = ARGV.include?("--force") || DRY_RUN
MAX_ITEMS = 5
MAX_AGE_H = 36
PAUSE_S = 10

SUBREDDITS = %w[cybersecurity netsec artificial LocalLLaMA ChatGPT OpenAI ClaudeAI MachineLearning sysadmin privacy
                AskNetsec cybersecurity_help].freeze

# Topics with a hub page. A thread needs the phrase and an AI word unless the phrase is AI-specific.
TOPICS = [
  [/prompt[- ]injection/i, "prompt-injection", "Prompt injection", true],
  [/llm ?jacking|stolen (api|openai|anthropic) key|api key (was )?(leaked|stolen|abused)|someone (used|is using) my (api|openai) key/i, "llmjacking", "LLMjacking", false],
  [/deepfake.{0,40}(scam|fraud|ceo|cfo|call|video call|impersonat)|voice clon.{0,30}(scam|fraud)/i, "deepfake-fraud", "Deepfake fraud", true],
  [/(ai|llm|chatgpt)[- ](generated|written|powered|assisted) (malware|ransomware|phishing)|malware (written|built|generated) (by|with) (ai|llm|chatgpt)/i, "ai-assisted-malware", "AI-assisted malware", true],
  [/(ai|llm)[- ]phishing|phishing.{0,30}(chatgpt|llm|ai[- ]generated)/i, "ai-phishing", "AI phishing", true],
  [/(malicious|poisoned|backdoor(ed)?) (model|package|extension|mcp server)|model poisoning|supply[- ]chain.{0,30}(ai|llm|hugging ?face|pypi model|mcp)/i, "ai-supply-chain", "AI supply chain", false],
  [/(agent|agentic|mcp).{0,40}(hijack|exploit|attack|vulnerab|compromis|exfiltrat|breach|hack)|(hijack|exploit|compromis|breach|hack)\w*.{0,40}(ai agent|coding agent|agentic|openai agent|agent)/i, "agent-hijack", "Agent hijack", false],
  [/(model|training data|system prompt|chat (history|logs)).{0,30}(leak|exposed|breach)/i, "model-data-leak", "Model & data leak", false],
  [/(state|nation)[- ]?(actor|sponsored|hackers?).{0,40}(ai|llm|gemini|chatgpt|claude)|\b(apt\d*|lazarus|sandworm|kimsuky)\b.{0,40}(ai|llm|gemini|chatgpt|claude)/i, "state-actor-ai-ops", "State actor AI ops", true]
].freeze
AI_WORD = /\b(ai|llm|llms|gpt|chatgpt|claude|gemini|copilot|openai|anthropic|agent|agents|agentic|mcp|model|cursor|api key|api keys)\b/i
SEC_WORD = /\b(exploit\w*|attack\w*|breach\w*|hack\w*|leak\w*|stolen|stole|steal\w*|vulnerab\w*|malware|scam\w*|fraud|incident|compromis\w*|cve|zero-day|0day|ransomware|phish\w*)\b/i
QUESTION = /\?|\b(anyone|has anybody|have you|how (do|can|should)|what (is|are|do)|is it|are there|examples? of|any (good|reliable)|looking for|recommend)\b/i
# Too common to identify a case on their own.
COMMON = Set.new(%w[ai llm llms openai chatgpt claude gemini google microsoft meta anthropic github copilot aws azure windows
                    linux android apple amazon cursor agent agents api key keys model models data security attack attackers
                    hackers malware phishing deepfake deepfakes prompt injection users user report reports new using used
                    via first million billion state chinese russian north korean iranian us uk eu government cloud
                    code coding open source server servers vulnerability flaw flaws credentials accounts account
                    january february march april june july august september october november december monday friday
                    reddit discord telegram whatsapp slack gmail youtube twitter facebook instagram tiktok linkedin
                    macos ios ipados readme wordpress m365 office365 outlook sharepoint excel ctrl cves edge chrome firefox safari qwen opus sonnet haiku llama mistral grok deepseek nvidia perplexity hugging face huggingface])
# Descriptive compounds ("LLM-based", "AI-powered") are not names either.
# What product and group names look like: PaperCut, GhostGPT, JINX-2401, METR, gpt-4o-mini.
BRANDLIKE = /[a-z][A-Z]|[A-Za-z]\d|\d[A-Za-z]|\A[A-Z]{4,}\z|[A-Z]-[A-Z]/
DESCRIPTIVE = /-(based|powered|driven|generated|assisted|enabled|style|like)\z/

def http_get(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |h|
    h.request(Net::HTTP::Get.new(uri, "User-Agent" => UA, "Accept" => "application/atom+xml"))
  end
end

def http_post_json(url, body, headers = {})
  uri = URI(url)
  req = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json; charset=utf-8" }.merge(headers))
  req.body = JSON.generate(body)
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 120) { |h| h.request(req) }
  raise "HTTP #{res.code} from #{uri.host}: #{res.body.to_s[0, 300]}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def text_of(html)
  CGI.unescapeHTML(CGI.unescapeHTML(html.to_s)).gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
end

# ---------- cases: what identifies each one ----------
def case_index
  cases = JSON.parse(File.read(CASES))
  # Words our own case text uses in lower case are ordinary English ("small", "actions"), not names.
  english = Set.new
  cases.each { |c| %w[title summary impact vector root_cause response attribution motive].each { |k| c[k].to_s.scan(/\b[a-z][a-z\-]{3,}\b/) { |w| english << w } } }
  strong = Set.new
  token_sets = cases.map do |c|
    # Proper names only: skip the title's first word ("Hundreds", "Attackers"), keep capitalised words after it.
    first, *rest = c["title"].to_s.split
    head = first.to_s =~ BRANDLIKE ? [first] : [] # "GhostGPT ..." is a name, "Hundreds ..." is not
    words = ((head + rest).join(" ") + " " + c["target"].to_s).scan(/[A-Za-z][A-Za-z0-9.\-]{3,}/)
    kept = words.select { |w| w =~ /[A-Z0-9]/ && !COMMON.include?(w.downcase) && !english.include?(w.downcase) && w !~ DESCRIPTIVE }
    kept.each { |w| strong << w.downcase if w =~ BRANDLIKE }
    names = kept.map(&:downcase)
    # Multi-word names ("Hugging Face", "Red Agent") count as one identifier.
    phrases = (c["title"].to_s.split.drop(1).join(" ") + " " + c["target"].to_s)
              .scan(/\b[A-Z][\w.\-]+(?: [A-Z][\w.\-]+){1,2}\b/).map(&:downcase)
              .reject { |ph| ph.split.all? { |w| COMMON.include?(w) || english.include?(w) } }
    (names + phrases).uniq
  end
  df = Hash.new(0)
  token_sets.each { |s| s.each { |t| df[t] += 1 } }
  cases.each_with_index.map do |c, i|
    codes = []
    codes += c["cve"].to_s.scan(/CVE-\d{4}-\d{4,}/i)
    codes += "#{c['actor']} #{c['title']}".scan(/\b(?:(?!CVE-)[A-Z]{2,}[A-Z0-9]*-\d{2,}|Storm-\d{3,}|UNC\d{3,}|APT\d{1,3}|TA\d{3,})\b/)
    { id: c["id"], title: c["title"], summary: c["summary"], category: c["category"],
      codes: codes.uniq, rare: token_sets[i].select { |t| df[t] <= 2 }, unique: token_sets[i].select { |t| df[t] <= 2 && strong.include?(t) },
      strong: token_sets[i].select { |t| strong.include?(t) || t.include?(" ") } }
  end
end

# A single name must be in the thread title; codes and two names may come from the body.
def match_case(text, idx, title = text)
  low = text.downcase
  low_title = title.downcase
  best = nil
  idx.each do |c|
    unique = c[:unique]
    code = c[:codes].find { |k| low.include?(k.downcase) }
    rare = c[:rare].select { |t| low =~ /\b#{Regexp.escape(t)}\b/ }
    # A matched phrase and its own words are one identifier, not several.
    rare = rare.reject { |t| !t.include?(" ") && rare.any? { |o| o.include?(" ") && o.split.include?(t) } }
    # One rare name is enough next to a security word; two rare names are enough on their own.
    score = (code ? 12 : 0) + ((rare.size >= 2 && rare.any? { |t| c[:strong].include?(t) }) || (rare.size == 1 && unique.include?(rare.first) && low_title =~ /\b#{Regexp.escape(rare.first)}\b/ && low =~ SEC_WORD) ? 10 : 0)
    next if score < 10 || (!code && !(low =~ AI_WORD) && rare.none? { |t| c[:strong].include?(t) })
    best = c.merge(score: score, why: code || rare.first(2).join(", ")) if best.nil? || score > best[:score]
  end
  best
end

def match_topic(text)
  TOPICS.each do |re, slug, label, ai_specific|
    next unless text =~ re
    next unless ai_specific || text =~ AI_WORD
    return { slug: slug, label: label }
  end
  nil
end

# ---------- Reddit ----------
def fetch_sub(sub)
  url = "https://www.reddit.com/r/#{sub}/new.rss?limit=100"
  2.times do |attempt|
    res = http_get(url)
    if res.code == "429" && attempt.zero?
      sleep 45
      next
    end
    return [[], "HTTP #{res.code}"] unless res.is_a?(Net::HTTPSuccess)
    body = res.body.force_encoding("UTF-8")
    posts = body.scan(%r{<entry>(.*?)</entry>}m).map do |(e)|
      {
        id: e[%r{<id>(.*?)</id>}, 1],
        sub: sub,
        title: CGI.unescapeHTML(e[%r{<title>(.*?)</title>}m, 1].to_s),
        url: e[%r{<link href="([^"]+)"}, 1],
        at: Time.parse(e[%r{<published>(.*?)</published>}, 1] || e[%r{<updated>(.*?)</updated>}, 1]),
        body: text_of(e[%r{<content[^>]*>(.*?)</content>}m, 1])[0, 1500]
      }
    end
    return [posts, "ok #{posts.size}"]
  end
  [[], "HTTP 429"]
rescue StandardError => e
  [[], e.class.name]
end

# ---------- drafts ----------
def drafts(picks)
  key = ENV["ANTHROPIC_API_KEY"].to_s.strip
  return picks.map { |p| template(p) } if key.empty?

  items = picks.each_with_index.map do |p, i|
    { n: i + 1, subreddit: p[:post][:sub], thread_title: p[:post][:title], thread_text: p[:post][:body][0, 800],
      link: p[:link], link_is: p[:case] ? "case file: #{p[:case][:title]} — #{p[:case][:summary]}" : "hub page listing all verified #{p[:topic][:label]} cases" }
  end
  prompt = <<~P
    You draft Reddit replies for the person who runs AI Threat Watch (aithreat.io), an open, sourced database of verified AI security incidents. He will read, edit and post each reply himself.
    For each thread below write one reply that:
    - answers or adds to the thread first, in 2 to 4 plain sentences, using only facts from the case summary given (never invent details);
    - then gives the link once, with a short disclosure such as "(I maintain this tracker)";
    - sounds like a knowledgeable person, not marketing: no exclamation marks, no emoji, no "check out", no hashtags;
    - if the link does not genuinely help this thread, returns exactly SKIP.
    Return only JSON: [{"n":1,"reply":"..."}, ...]

    Threads:
    #{JSON.pretty_generate(items)}
  P
  res = http_post_json("https://api.anthropic.com/v1/messages",
                       { model: MODEL, max_tokens: 3000, messages: [{ role: "user", content: prompt }] },
                       "x-api-key" => key, "anthropic-version" => "2023-06-01")
  out = JSON.parse(res["content"].map { |c| c["text"] }.join[/\[.*\]/m])
  picks.each_with_index.map { |p, i| out.find { |o| o["n"] == i + 1 }&.dig("reply") || template(p) }
rescue StandardError => e
  warn "reddit: drafts failed (#{e.message[0, 200]}), using the template"
  picks.map { |p| template(p) }
end

def template(p)
  what = p[:case] ? p[:case][:summary] : "There are a number of verified #{p[:topic][:label].downcase} cases with primary sources."
  "#{what} Sourced write-up: #{p[:link]} (I maintain this tracker)"
end

# ---------- Telegram ----------
def send_telegram(html)
  token = ENV["TELEGRAM_BOT_TOKEN"].to_s.strip
  chat = ENV["TELEGRAM_ALERT_CHAT_ID"].to_s.strip
  raise "TELEGRAM_BOT_TOKEN or TELEGRAM_ALERT_CHAT_ID not set" if token.empty? || chat.empty?

  # Telegram caps a message at 4096 characters; split on item boundaries.
  html.split("\n\n⁣").each do |part|
    http_post_json("https://api.telegram.org/bot#{token}/sendMessage",
                   { chat_id: chat, text: part, parse_mode: "HTML", link_preview_options: { is_disabled: true } })
    sleep 1
  end
end

# ---------- main ----------
state = File.exist?(STATE) ? JSON.parse(File.read(STATE)) : { "last_run" => nil, "sent" => [] }
today = Time.now.utc.strftime("%Y-%m-%d")
unless FORCE
  if state["last_run"] == today || Time.now.utc.hour < 5
    puts "reddit: not due (last run #{state['last_run'] || 'never'})"
    exit 0
  end
end

if !DRY_RUN && (ENV["TELEGRAM_BOT_TOKEN"].to_s.strip.empty? || ENV["TELEGRAM_ALERT_CHAT_ID"].to_s.strip.empty?)
  puts "reddit: skipped (TELEGRAM_BOT_TOKEN or TELEGRAM_ALERT_CHAT_ID not set)"
  exit 0
end

idx = case_index
sent = Set.new(state["sent"])
statuses = {}
posts = []
SUBREDDITS.each_with_index do |sub, i|
  sleep PAUSE_S if i.positive?
  got, status = fetch_sub(sub)
  statuses[sub] = status
  posts.concat(got)
end
puts "reddit: " + statuses.map { |k, v| "r/#{k} #{v}" }.join(", ")

cutoff = Time.now.utc - MAX_AGE_H * 3600
picks = posts.uniq { |p| p[:id] }.map do |p|
  next if p[:id].nil? || sent.include?(p[:id]) || p[:at] < cutoff
  text = "#{p[:title]} #{p[:body]}"
  next if text.include?("aithreat")

  c = match_case(text, idx, p[:title])
  t = c ? nil : match_topic(p[:title])
  next unless c || t

  score = (c ? c[:score] : 5) + (p[:title] =~ QUESTION ? 4 : 0) + (p[:at] > Time.now.utc - 12 * 3600 ? 1 : 0)
  link = c ? "#{BASE}/cases/#{c[:id]}/" : "#{BASE}/cases/category/#{t[:slug]}/"
  { post: p, case: c, topic: t, link: link, score: score }
end.compact.sort_by { |x| -x[:score] }.first(MAX_ITEMS)

blocked = statuses.values.none? { |s| s.start_with?("ok") }
h = ->(s) { CGI.escapeHTML(s.to_s) }
message =
  if blocked
    "⚠️ <b>Reddit check failed today</b>\nEvery subreddit refused the robot (#{h.(statuses.values.uniq.join(', '))}). Nothing to do; it tries again tomorrow."
  elsif picks.empty?
    "🔎 <b>Reddit today:</b> no new threads that a case file answers. Checked #{statuses.count { |_, s| s.start_with?('ok') }} subreddits."
  else
    replies = drafts(picks)
    kept = picks.zip(replies).reject { |_, r| r.to_s.strip == "SKIP" }
    if kept.empty?
      "🔎 <b>Reddit today:</b> #{picks.size} possible threads, none where a link would genuinely help."
    else
      head = "🔎 <b>Reddit today: #{kept.size} thread#{kept.size == 1 ? '' : 's'} a case file answers</b>\nRead the thread, edit the draft, post it yourself. Skip any that feel forced."
      items = kept.each_with_index.map do |(p, reply), i|
        why = p[:case] ? "matches #{h.(p[:case][:why])} → #{h.(p[:case][:title])}" : "topic: #{h.(p[:topic][:label])}"
        "<b>#{i + 1}. r/#{h.(p[:post][:sub])}</b>: <a href=\"#{h.(p[:post][:url])}\">#{h.(p[:post][:title][0, 160])}</a>\n" \
          "<i>#{why}</i>\n<pre>#{h.(reply)}</pre>"
      end
      ([head] + items).join("\n\n⁣")
    end
  end

if DRY_RUN
  puts message.gsub("⁣", "")
  exit 0
end

send_telegram(message)
puts "reddit: sent #{picks.size} picks"
state["last_run"] = today
state["sent"] = (state["sent"] + picks.map { |p| p[:post][:id] }).last(3000)
File.write(STATE, JSON.pretty_generate(state) + "\n")
