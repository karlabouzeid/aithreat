#!/usr/bin/env ruby
# AI Threat Watch wire updater. Runs every 30 minutes in GitHub Actions.
# 1. Pull security news feeds. 2. Keep AI-security stories. 3. Ask Claude to triage
#    and draft case files for genuinely new incidents. 4. Write site/data/*.json.
require "rss"
require "json"
require "net/http"
require "uri"
require "time"
require "digest"
require "openssl"

ROOT = File.expand_path("..", __dir__)
SITE = File.join(ROOT, "site")
DATA = File.join(SITE, "data")
FEEDS = JSON.parse(File.read(File.join(ROOT, "config", "feeds.json")))
WIRE_PATH = File.join(DATA, "wire.json")
CAND_PATH = File.join(DATA, "candidates.json")
STATUS_PATH = File.join(DATA, "status.json")
INC_PATH = File.join(DATA, "incidents.en.json")
APPROVED_PATH = File.join(ROOT, "config", "approved.txt")
REJECTED_PATH = File.join(ROOT, "config", "rejected.txt")
UA = "AIThreatWatch/1.0 (+https://aithreat.io; feed reader)"
KEEP_DAYS = 14
MAX_WIRE = 800
MODEL = ENV.fetch("ATW_MODEL", "claude-sonnet-5-5")

AI_RE = /\b(AI|A\.I\.|artificial intelligence|LLMs?|GPT(-\d)?|ChatGPT|Claude|Gemini|Copilot|OpenAI|Anthropic|DeepSeek|Mistral|Llama|Grok|xAI|prompt[- ]injection|jailbreak|deepfakes?|voice[- ]clon|agentic|AI agents?|MCP|model context protocol|machine[- ]learning|neural|chatbots?|Ollama|Hugging ?Face|LangChain|LangFlow|Flowise|vLLM|LiteLLM|Vertex AI|Bedrock|Azure OpenAI|coding agents?|Cursor|Codex|RAG|vector database|OpenClaw|Moltbook)\b/i
SEC_RE = /\b(hack(ed|ers?|ing)?|breach(ed|es)?|vulnerabilit(y|ies)|exploit(ed|s|ation)?|malware|phish(ing|ers?)?|smishing|fraud|scam(s|mers?)?|leak(ed|s)?|expos(ed|es|ure)|attack(s|ers?|ed)?|CVE-\d{4}-\d+|ransomware|extortion|stolen|theft|botnet|RCE|zero[- ]day|backdoor|hijack(ed|ing)?|compromise[ds]?|injection|data loss|infostealer|supply[- ]chain|credential|token theft|unauthori[sz]ed|espionage|APT\d*|threat actor|state[- ]sponsored|disinformation|impersonat)/i

def log(msg); $stderr.puts("[update] #{msg}"); end

def http_get(url, limit = 5)
  raise "too many redirects" if limit == 0
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 10
  http.read_timeout = 20
  req = Net::HTTP::Get.new(uri.request_uri, { "User-Agent" => UA, "Accept" => "*/*" })
  res = http.request(req)
  case res
  when Net::HTTPSuccess then res.body
  when Net::HTTPRedirection then http_get(URI.join(url, res["location"]).to_s, limit - 1)
  else raise "HTTP #{res.code}"
  end
end

def strip_html(s)
  s.to_s.gsub(/<[^>]+>/, " ").gsub(/&nbsp;|&#160;/, " ").gsub(/&amp;/, "&").gsub(/&lt;/, "<").gsub(/&gt;/, ">").gsub(/&quot;/, '"').gsub(/&#39;|&apos;/, "'").gsub(/\s+/, " ").strip
end

def norm_url(u)
  uri = URI(u.strip) rescue (return u.strip)
  uri.fragment = nil
  if uri.query
    keep = URI.decode_www_form(uri.query).reject { |k, _| k =~ /^(utm_|fbclid|gclid|ref$|source$)/i }
    uri.query = keep.empty? ? nil : URI.encode_www_form(keep)
  end
  uri.to_s.sub(/\/$/, "")
end

KEV_AI_RE = /\b(AI|LLM|GPT|OpenAI|Anthropic|Langflow|Flowise|LiteLLM|Ollama|vLLM|Ray|Anyscale|Hugging ?Face|Gradio|Open WebUI|AnythingLLM|Dify|n8n|LangChain|MCP|Triton|NVIDIA|PyTorch|TensorFlow|Jupyter|MLflow|Kubeflow|model|agent|chatbot|machine learning)\b/i
def parse_kev(name, body)
  data = JSON.parse(body)
  (data["vulnerabilities"] || []).select { |v| "#{v['vendorProject']} #{v['product']} #{v['vulnerabilityName']} #{v['shortDescription']}" =~ KEV_AI_RE }.map do |v|
    { title: "#{v['cveID']}: #{v['vendorProject']} #{v['product']} actively exploited", url: "https://www.cisa.gov/known-exploited-vulnerabilities-catalog?search_api_fulltext=#{v['cveID']}", published: v["dateAdded"], summary: strip_html(v["shortDescription"].to_s)[0, 400], publisher: "CISA KEV", source: name }
  end
rescue => e
  log "kev parse failed: #{e.class} #{e.message}"
  []
end

def parse_feed(name, body)
  feed = RSS::Parser.parse(body, false)
  items = []
  if feed.respond_to?(:items) && feed.feed_type == "rss"
    feed.items.each do |it|
      publisher = (it.source ? it.source.content.to_s.strip : "") rescue ""
      title = strip_html(it.title)
      title = title.sub(/\s+-\s+#{Regexp.escape(publisher)}\z/, "") unless publisher.empty?
      items << { title: title, url: it.link.to_s, published: (it.date || it.pubDate rescue nil), summary: strip_html(it.description.to_s)[0, 400], publisher: publisher }
    end
  elsif feed.respond_to?(:entries)
    feed.entries.each do |e|
      link = (e.links.find { |l| l.rel.nil? || l.rel == "alternate" } || e.links.first)&.href.to_s
      pub = (e.published&.content || e.updated&.content rescue nil)
      items << { title: strip_html(e.title&.content), url: link, published: pub, summary: strip_html((e.summary&.content || e.content&.content).to_s)[0, 400] }
    end
  end
  items.map { |i| i.merge(source: name) }
rescue => e
  log "parse failed for #{name}: #{e.class} #{e.message}"
  []
end

def relevant?(item, ai_only_source)
  text = "#{item[:title]} #{item[:summary]}"
  ai = ai_only_source || text =~ AI_RE
  sec = text =~ SEC_RE
  ai && (sec || ai_only_source)
end

# ---------- 1. fetch ----------
now = Time.now.utc
existing = File.exist?(WIRE_PATH) ? JSON.parse(File.read(WIRE_PATH)) : []
require "set"
known = existing.map { |w| w["id"] }.to_set
feeds_ok, feeds_failed, fresh = [], [], []
prev_ok = (File.exist?(STATUS_PATH) ? (JSON.parse(File.read(STATUS_PATH))["feeds_ok"] rescue []) : []) || []
FEEDS.each do |f|
  begin
    first_read = !prev_ok.include?(f["name"]) # a feed's first read brings its archive; don't present old articles as news
    body = http_get(f["url"])
    items = f["json"] == "kev" ? parse_kev(f["name"], body) : parse_feed(f["name"], body)
    kept = items.select { |i| i[:url] && !i[:url].empty? && relevant?(i, f["ai_only"]) }
    kept.each do |i|
      url = norm_url(i[:url])
      id = Digest::SHA1.hexdigest(url)[0, 12]
      next if known.include?(id)
      pub = (Time.parse(i[:published].to_s).utc rescue now)
      pub = now if pub > now + 3600
      summary = i[:summary].to_s
      summary = "" if f["google"] # Google's summary is only the headline and publisher again
      src = (i[:publisher] && !i[:publisher].empty?) ? i[:publisher] : i[:source]
      seen = (first_read && pub < now - 48 * 3600) ? pub : now
      fresh << { "id" => id, "title" => i[:title][0, 200], "url" => url, "source" => src, "via" => f["name"], "lang" => (f["lang"] || "en"), "published" => pub.iso8601, "seen" => seen.iso8601, "summary" => summary }
      known << id
    end
    feeds_ok << f["name"]
    log "#{f['name']}: #{items.size} items, #{kept.size} relevant"
  rescue => e
    feeds_failed << f["name"]
    log "#{f['name']} failed: #{e.class} #{e.message}"
  end
end
# dedupe near-identical titles among fresh items
title_key = ->(s) { s.to_s.downcase.gsub(/[[:punct:]\s]+/, " ").strip }
seen_titles = existing.map { |w| title_key.(w["title"]) }
fresh = fresh.reject do |w|
  key = title_key.(w["title"])
  dup = seen_titles.include?(key); seen_titles << key; dup
end
log "new items: #{fresh.size}"

# ---------- 2. triage with Claude (optional) ----------
incidents = File.exist?(INC_PATH) ? JSON.parse(File.read(INC_PATH)) : []
candidates = File.exist?(CAND_PATH) ? JSON.parse(File.read(CAND_PATH)) : []
api_key = ENV["ANTHROPIC_API_KEY"].to_s.strip
api_key = nil if api_key.empty?
triage_note = nil
if api_key && !fresh.empty?
  recent_titles = (incidents.map { |i| "#{i['date']} #{i['title']}" } + candidates.map { |c| "#{c['date']} #{c['title']}" }).last(120)
  known_cats = ["Prompt injection", "Deepfake fraud", "AI-assisted malware", "AI supply chain", "Model & data leak", "LLMjacking", "Agent hijack", "AI phishing", "State actor AI ops"]
  build_prompt = lambda do |batch, offset|
  <<~P
    You are the triage editor of AI Threat Watch, a public tracker of AI security incidents (attacks ON AI systems and attacks carried out WITH AI).
    Today is #{now.strftime('%Y-%m-%d')}. Below are new headlines from security and general news feeds in several languages, each with an index, title, source and summary. Headlines may be in English, French, Spanish, Arabic or Chinese; always write "tag", "one_line" and every draft field in English.

    For EACH item return an object:
    - "i": the index
    - "keep": true if it is about AI security (an AI system attacked, abused, leaking, or AI used to attack); false for generic security news, product marketing, opinion with no event, or unrelated AI news
    - "kind": one of "incident" (a specific real-world event with a victim), "vulnerability" (a flaw disclosed, no confirmed abuse), "research", "policy", "vendor-report", "other"
    - "tag": 2-4 word label for the wire, e.g. "Prompt injection", "Deepfake fraud", "LLM data leak"
    - "one_line": one neutral sentence (<=140 chars) saying what happened, for the wire
    - "new_incident": true ONLY if kind is "incident" or an actively exploited "vulnerability", the event is specific and credible, and it is NOT already in the known list below
    - if new_incident is true, also "draft": {"id": kebab-case slug <=40 chars, "date": "YYYY-MM-DD" (event or report date), "title": <=90 chars, "category": one of #{known_cats.to_json}, "direction": "on-ai" or "with-ai", "severity": "critical"|"high"|"medium"|"low", "country": ISO-3166 alpha-2 or "GL" for global/multi-country, "region": "North America"|"Europe"|"Asia-Pacific"|"Latin America"|"Middle East & Africa"|"Global", "target": <=60 chars, "loss_usd": number or null, "summary": <=220 chars, "actor": <=80 chars or "Unknown", "actor_type": "state"|"criminal"|"insider"|"researcher"|"hacktivist"|"accident"|"autonomous-ai"|"unknown", "attribution": <=200 chars, "motive": <=160 chars, "vector": <=200 chars, "root_cause": <=220 chars, "impact": <=260 chars, "response": <=260 chars, "status": "resolved"|"patched"|"contained"|"ongoing"|"under investigation"|"unresolved", "cve": string or null, "confidence": 0.0-1.0 (how sure you are this is a real, distinct, correctly summarised AI security incident based ONLY on the headline and summary)}
    Use only facts in the headline and summary; write "Unknown" where the text does not say. Never invent numbers.

    Known incidents (do not duplicate):
    #{recent_titles.join("\n")}

    New items:
    #{batch.each_with_index.map { |w, n| "#{offset + n}. [#{w['source']}] #{w['title']} — #{w['summary'][0, 300]}" }.join("\n")}

    Reply with ONLY a JSON array, no prose, no code fences.
  P
  end
  by_i = {}
  batches_ok, batches_failed, sample = 0, 0, nil
  fresh.each_slice(25).with_index do |batch, bi|
    offset = bi * 25
    begin
      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true; http.read_timeout = 180
      req = Net::HTTP::Post.new(uri.path, { "content-type" => "application/json", "x-api-key" => api_key, "anthropic-version" => "2023-06-01" })
      req.body = { model: MODEL, max_tokens: 12000, messages: [{ role: "user", content: build_prompt.(batch, offset) }] }.to_json
      res = http.request(req)
      raise "API #{res.code}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
      body = JSON.parse(res.body)
      text = body["content"].map { |c| c["text"] }.join.gsub(/```(?:json)?/, "")
      json = text[/\[.*\]/m] or raise "no JSON (stop=#{body['stop_reason']}): #{text[0, 160]}"
      verdicts = JSON.parse(json)
      verdicts.each { |v| by_i[v["i"].to_i] = v }
      batches_ok += 1
    rescue => e
      batches_failed += 1
      sample ||= e.message[0, 220]
      log "triage batch #{bi} failed: #{e.class} #{e.message[0, 160]}"
    end
  end
  begin
    raise "all #{batches_failed} batches failed: #{sample}" if batches_ok == 0
    kept = []
    fresh.each_with_index do |w, n|
      v = by_i[n]
      next unless v && v["keep"]
      w["kind"] = v["kind"]; w["tag"] = v["tag"]; w["one_line"] = v["one_line"]
      if v["new_incident"] && v["draft"].is_a?(Hash)
        d = v["draft"]
        d["id"] = d["id"].to_s.downcase.gsub(/[^a-z0-9-]+/, "-").gsub(/^-|-$/, "")[0, 40]
        d["id"] = "#{d['id']}-#{w['id'][0, 4]}" if (incidents + candidates).any? { |x| x["id"] == d["id"] }
        d["source"] = w["source"]; d["url"] = w["url"]
        d["sources"] = [{ "name" => w["source"], "url" => w["url"] }]
        d["timeline"] = [{ "date" => d["date"], "event" => "Reported by #{w['source']}" }]
        d["verified"] = false; d["drafted_at"] = now.iso8601; d["wire_id"] = w["id"]
        d["confidence"] = d["confidence"].to_f
        candidates << d
        w["candidate_id"] = d["id"]
        log "candidate: #{d['id']} (#{d['confidence']})"
      end
      kept << w
    end
    triage_note = "triaged #{fresh.size} items with #{MODEL} in #{batches_ok} batches (#{batches_failed} failed#{sample ? ': ' + sample : ''}); kept #{kept.size}"
    fresh = kept
  rescue => e
    log "triage failed: #{e.class} #{e.message}"
    triage_note = "triage failed: #{e.message[0, 120]}"
  end
elsif fresh.any?
  triage_note = "no ANTHROPIC_API_KEY: keyword filter only"
end

# ---------- 3. apply editor decisions (config/approved.txt, config/rejected.txt) ----------
read_ids = ->(p) { File.exist?(p) ? File.read(p).lines.map { |l| l.strip.split(/\s+/).first }.compact.reject { |l| l.empty? || l.start_with?("#") } : [] }
approved, rejected = read_ids.(APPROVED_PATH), read_ids.(REJECTED_PATH)
promoted = candidates.select { |c| approved.include?(c["id"]) }
promoted.each do |c|
  next if incidents.any? { |i| i["id"] == c["id"] }
  inc = c.reject { |k, _| %w[verified drafted_at wire_id confidence].include?(k) }
  incidents << inc
  log "promoted to verified: #{c['id']}"
end
incidents.sort_by! { |i| i["date"] }
candidates.reject! { |c| approved.include?(c["id"]) || rejected.include?(c["id"]) }
candidates.reject! { |c| (now - Time.parse(c["drafted_at"])) > 30 * 86400 } # stale drafts expire

# ---------- 4. write ----------
cutoff = now - KEEP_DAYS * 86400
wire = (fresh + existing).uniq { |w| w["id"] }.select { |w| Time.parse(w["published"]) >= cutoff }
wire.each { |w| w["seen"] = w["published"] if Time.parse(w["seen"]) - Time.parse(w["published"]) > 48 * 3600 } # archive items discovered late are not news
wire = wire.sort_by { |w| [w["seen"], w["published"]] }.reverse.first(MAX_WIRE)
File.write(WIRE_PATH, JSON.pretty_generate(wire))
File.write(CAND_PATH, JSON.pretty_generate(candidates))
File.write(INC_PATH, JSON.pretty_generate(incidents)) if promoted.any?
esc = ->(s) { s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;") }
rss_items = wire.first(60).map do |w|
  desc = [w["one_line"], w["summary"]].compact.reject(&:empty?).first.to_s
  "<item><title>#{esc.(w['title'])}</title><link>#{esc.(w['url'])}</link><guid isPermaLink=\"false\">#{w['id']}</guid><pubDate>#{Time.parse(w['published']).rfc2822}</pubDate><category>#{esc.(w['kind'] || 'untagged')}</category><description>#{esc.("#{w['source']}: #{desc}")}</description></item>"
end
File.write(File.join(SITE, "feed.xml"), %(<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>AI Threat Watch wire</title><link>https://aithreat.io/#wire</link><description>AI security headlines from vetted sources, refreshed every 30 minutes.</description><lastBuildDate>#{now.rfc2822}</lastBuildDate>#{rss_items.join}</channel></rss>))

status = { "updated_at" => now.iso8601, "wire_items" => wire.size, "new_items" => fresh.size, "candidates" => candidates.size, "incidents" => incidents.size, "feeds_ok" => feeds_ok, "feeds_failed" => feeds_failed, "triage" => triage_note }
File.write(STATUS_PATH, JSON.pretty_generate(status))
log status.to_json
