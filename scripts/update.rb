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
TRIAGED_PATH = File.join(DATA, "triaged.json") # story id => day it was sorted, so it is never sent to Claude twice
STATUS_PATH = File.join(DATA, "status.json")
INC_PATH = File.join(DATA, "incidents.en.json")
APPROVED_PATH = File.join(ROOT, "config", "approved.txt")
REJECTED_PATH = File.join(ROOT, "config", "rejected.txt")
UA = "AIThreatWatch/1.0 (+https://aithreat.io; feed reader)"
KEEP_DAYS = 14
MAX_WIRE = 800
MODEL = ENV.fetch("ATW_MODEL", "claude-sonnet-5-5")

AI_RE = /\b(AI|A\.I\.|artificial intelligence|LLMs?|GPT(-\d)?|ChatGPT|Claude|Gemini|Copilot|OpenAI|Anthropic|DeepSeek|Mistral|Llama|Grok|xAI|prompt[- ]injection|jailbreak|deepfakes?|voice[- ]clon|agentic|AI agents?|MCP|model context protocol|machine[- ]learning|neural|chatbots?|Ollama|Hugging ?Face|LangChain|LangFlow|Flowise|vLLM|LiteLLM|Vertex AI|Bedrock|Azure OpenAI|coding agents?|Cursor|Codex|RAG|vector database|OpenClaw|Moltbook)\b/i
SEC_RE = /\b(hack(ed|ers?|ing)?|breach(ed|es)?|vulnerabilit(y|ies)|exploit(ed|s|ation)?|malware|phish(ing|ers?)?|smishing|fraud|scam(s|mers?)?|leak(ed|s)?|expos(ed|es|ure)|attack(s|ers?|ed)?|CVE-\d{4}-\d+|ransomware|extortion|stolen|theft|botnet|RCE|zero[- ]day|backdoor|hijack(ed|ing)?|compromise[ds]?|injection|data loss|infostealer|supply[- ]chain|credential|token theft|unauthori[sz]ed|espionage|APT\d*|threat actor|state[- ]sponsored|disinformation|impersonat|suicid(e|al)|self[- ]harm|wrongful death|psychosis|delusion(s|al)?|mental health crisis)/i

def log(msg); $stderr.puts("[update] #{msg}"); end

def http_get(url, limit = 5)
  raise "too many redirects" if limit == 0
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = 10
  http.read_timeout = 20
  headers = { "User-Agent" => UA, "Accept" => "*/*" }
  headers["Authorization"] = "Bearer #{ENV['GITHUB_TOKEN']}" if uri.host == "api.github.com" && !ENV["GITHUB_TOKEN"].to_s.empty?
  req = Net::HTTP::Get.new(uri.request_uri, headers)
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

AI_PKGS = %w[langchain langchain-core langchain-community llama-index llama_index vllm litellm ollama gradio mlflow transformers torch pytorch tensorflow keras huggingface-hub huggingface_hub diffusers openai anthropic langflow flowise dify open-webui anythingllm n8n mcp fastmcp autogen crewai semantic-kernel llama.cpp llama-cpp-python triton ray jupyter streamlit chromadb qdrant weaviate pinecone lancedb milvus guardrails haystack dspy instructor pydantic-ai smolagents browser-use]
def parse_ghsa(name, body)
  JSON.parse(body).select { |a|
    pkgs = (a["vulnerabilities"] || []).map { |v| v.dig("package", "name").to_s.downcase }
    pkgs.any? { |p| AI_PKGS.include?(p) } || "#{a['summary']} #{a['description']}" =~ AI_RE
  }.map { |a|
    pk = (a["vulnerabilities"] || []).map { |v| v.dig("package", "name") }.compact.uniq.join(", ")
    { title: "#{a['ghsa_id']}#{a['cve_id'] ? ' / ' + a['cve_id'] : ''}: #{a['summary']} (#{pk}, #{a['severity']})", url: a["html_url"], published: a["published_at"], summary: strip_html(a["description"].to_s)[0, 400], publisher: "GitHub Advisory Database", source: name }
  }
rescue => e
  log "ghsa parse failed: #{e.class} #{e.message}"; []
end

def parse_hn(name, body)
  JSON.parse(body)["hits"].to_a.map { |h|
    url = h["url"].to_s.empty? ? "https://news.ycombinator.com/item?id=#{h['objectID']}" : h["url"]
    host = (URI(url).host.to_s.sub(/^www\./, "") rescue "")
    { title: h["title"].to_s, url: url, published: h["created_at"], summary: "#{h['points']} points, #{h['num_comments']} comments on Hacker News", publisher: (host.empty? ? "Hacker News" : "#{host} via Hacker News"), source: name }
  }
rescue => e
  log "hn parse failed: #{e.class} #{e.message}"; []
end

def parse_courtlistener(name, body)
  JSON.parse(body)["results"].to_a.map { |r|
    path = r["docket_absolute_url"] || r["absolute_url"]
    next nil if path.to_s.empty? || r["court"].to_s =~ /bankruptcy/i
    snippet = (r["recap_documents"] || []).map { |d| strip_html(d["snippet"].to_s) }.reject(&:empty?).first.to_s
    next nil unless "#{r['caseName']} #{r['cause']} #{snippet}" =~ /deepfake|voice[- ]?clon|AI[- ]generated|artificial intelligence|chatbot|large language model/i
    { title: "Court filing: #{r['caseName']} (#{r['court']})", url: "https://www.courtlistener.com#{path}", published: r["dateFiled"], summary: "Docket #{r['docketNumber']}, filed #{r['dateFiled']}#{r['cause'].to_s.empty? ? '' : ', ' + r['cause']}. #{snippet}"[0, 400], publisher: "CourtListener (RECAP)", source: name }
  }.compact
rescue => e
  log "courtlistener parse failed: #{e.class} #{e.message}"; []
end

def parse_ghrepos(name, body)
  JSON.parse(body)["items"].to_a.map { |r|
    { title: "#{r['full_name']}: #{r['description'].to_s[0, 120]}", url: r["html_url"], published: r["created_at"], summary: "New GitHub repository, #{r['stargazers_count']} stars. #{r['description']}".to_s[0, 400], publisher: "GitHub", source: name }
  }
rescue => e
  log "ghrepos parse failed: #{e.class} #{e.message}"; []
end

def parse_bsky(name, body)
  JSON.parse(body)["posts"].to_a.map { |p|
    handle = p.dig("author", "handle"); rkey = p["uri"].to_s.split("/").last
    text = p.dig("record", "text").to_s.gsub(/\s+/, " ").strip
    { title: text[0, 140], url: "https://bsky.app/profile/#{handle}/post/#{rkey}", published: p.dig("record", "createdAt"), summary: text[0, 400], publisher: "Bluesky @#{handle}", source: name }
  }
rescue => e
  log "bsky parse failed: #{e.class} #{e.message}"; []
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

# Official sources (governments, regulators, central banks) speak of risk, resilience and
# exercises more than of attacks, so their items also pass on those words.
OFFICIAL_RE = /\b(cyber\w*|threats?|risks?|resilien\w*|misuse|safety|security|warn(s|ed|ing)?|simulat\w*|stress[- ]test\w*|exercises?)\b/i

def relevant?(item, ai_only_source, official = false)
  text = "#{item[:title]} #{item[:summary]}"
  ai = ai_only_source || text =~ AI_RE
  sec = text =~ SEC_RE || (official && text =~ OFFICIAL_RE)
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
    urls = (f["urls"] || [f["url"]]).map { |u| u.gsub(/\{\{date-(\d+)\}\}/) { (now - $1.to_i * 86400).strftime("%Y-%m-%d") } }
    items = urls.flat_map do |u|
      body = http_get(u)
      case f["json"]
      when "kev" then parse_kev(f["name"], body)
      when "ghsa" then parse_ghsa(f["name"], body)
      when "hn" then parse_hn(f["name"], body)
      when "courtlistener" then parse_courtlistener(f["name"], body)
      when "ghrepos" then parse_ghrepos(f["name"], body)
      when "bsky" then parse_bsky(f["name"], body)
      else parse_feed(f["name"], body)
      end
    end
    kept = items.select { |i| i[:url] && !i[:url].empty? && relevant?(i, f["ai_only"], f["official"]) }
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
# Stories Claude already sorted and dropped are not in the wire, so the title check above
# misses them; without this they were re-sorted (and paid for) on every run.
triaged = (JSON.parse(File.read(TRIAGED_PATH)) rescue {})
triaged = {} unless triaged.is_a?(Hash)
triaged.select! { |_, d| d >= (now - (KEEP_DAYS + 2) * 86400).strftime("%Y-%m-%d") }
fresh = fresh.reject { |w| triaged.key?(w["id"]) }
log "new items: #{fresh.size}"
# Wire stories stored unsorted (triage was down when they arrived) go back through triage,
# a slice per run; dropped ones leave the wire, kept ones come back with their tags.
if !ENV["ANTHROPIC_API_KEY"].to_s.strip.empty?
  backlog = existing.select { |w| (w["kind"].nil? && !triaged.key?(w["id"])) || (!w["kind"].nil? && !w.key?("sector")) }.first(250)
  if backlog.any?
    ids = backlog.map { |w| w["id"] }
    existing = existing.reject { |w| ids.include?(w["id"]) }
    fresh += backlog
    log "unsorted wire stories sent back to triage: #{backlog.size}"
  end
end

# ---------- 2. triage with Claude (optional) ----------
incidents = File.exist?(INC_PATH) ? JSON.parse(File.read(INC_PATH)) : []
candidates = File.exist?(CAND_PATH) ? JSON.parse(File.read(CAND_PATH)) : []
api_key = ENV["ANTHROPIC_API_KEY"].to_s.strip
api_key = nil if api_key.empty?
triage_note = nil
warnings_new = []
if api_key && !fresh.empty?
  recent_titles = (incidents.map { |i| "#{i['date']} #{i['title']}" } + candidates.map { |c| "#{c['date']} #{c['title']}" }).last(120)
  known_cats = ["Prompt injection", "Deepfake fraud", "AI-assisted malware", "AI supply chain", "Model & data leak", "LLMjacking", "Agent hijack", "AI phishing", "State actor AI ops", "Chatbot harm", "Deepfake abuse", "AI misfire", "AI exam fraud"]
  build_prompt = lambda do |batch, offset|
  <<~P
    You are the triage editor of AI Threat Watch, a public tracker of AI security incidents (attacks ON AI systems and attacks carried out WITH AI) and of serious harm caused BY AI systems to people (category "Chatbot harm": an AI chatbot or companion app alleged in a lawsuit, an official investigation or credible reporting to have contributed to a death, suicide, self-harm, violence or a serious mental health crisis).
    Today is #{now.strftime('%Y-%m-%d')}. Below are new headlines from security and general news feeds in several languages, each with an index, title, source and summary. Headlines may be in English, French, Spanish, Arabic or Chinese; always write "tag", "one_line" and every draft field in English.

    For EACH item return an object:
    - "i": the index
    - "keep": true if it is about AI security (an AI system attacked, abused, leaking, or AI used to attack); also true for a specific case of serious harm to a person attributed to an AI chatbot or companion (lawsuit, inquest, police or regulator action); also true for a specific case of AI deepfakes used to sexually abuse, harass or defame a real person (for example pupils or teachers), an AI safety or monitoring tool that wrongly flagged, missed or exposed people, or organised exam cheating with AI (category "AI exam fraud"); false for generic security news, product marketing, opinion with no event, general debate about AI and mental health, or unrelated AI news
    - "kind": one of "incident" (a specific real-world event with a victim), "vulnerability" (a flaw disclosed, no confirmed abuse), "warning" (a public warning, exercise or simulation, formal advisory or binding rule about AI-related security risk, issued by a head of state or government, a minister, a central bank, a regulator, an election authority, an intergovernmental body such as the G7, G20, UN, EU, NATO or FSB, a national cyber or security agency, or a legislature; reporting about such a statement counts, commentary by companies, analysts or influencers does not), "research", "policy" (other policy news), "vendor-report", "other"
    - "sector": the sector most concerned, one of "Financial services"|"Government & public sector"|"Technology & AI vendors"|"Healthcare"|"Media & entertainment"|"Retail & consumer brands"|"Education & research"|"Energy, industrial & infrastructure"|"Defence & security"|"Politics & elections"|"Individuals & consumers"|"Multiple / cross-sector"|"Unknown"
    - if kind is "warning", also "warning": {"who": issuer as named in the text (<=80 chars), "who_type": "head_of_government"|"minister"|"central_bank"|"regulator"|"intergovernmental"|"security_agency"|"legislature", "country": ISO 3166 alpha-2, "EU" or "INT", "type": "warning"|"exercise"|"advisory"|"rule", "sectors": array of the sectors concerned (same list), "title": neutral headline <=120 chars, "summary": what was said or decided, facts only, <=280 chars}. Never present speculation or a forecast as a fact; attribute it to the issuer.
    - "tag": 2-4 word label for the wire, e.g. "Prompt injection", "Deepfake fraud", "LLM data leak"
    - "one_line": one neutral sentence (<=140 chars) saying what happened, for the wire
    - "new_incident": true ONLY if kind is "incident" or an actively exploited "vulnerability", the event is specific and credible, and it is NOT already in the known list below
    - if new_incident is true, also "draft": {"id": kebab-case slug <=40 chars, "date": "YYYY-MM-DD" (event or report date), "title": <=90 chars, "category": one of #{known_cats.to_json}, "direction": "on-ai" or "with-ai" (Deepfake abuse and AI exam fraud are with-ai), or "ai-harm" for Chatbot harm and AI misfire, "severity": "critical"|"high"|"medium"|"low", "country": ISO-3166 alpha-2 or "GL" for global/multi-country, "region": "North America"|"Europe"|"Asia-Pacific"|"Latin America"|"Middle East & Africa"|"Global", "target": <=60 chars, "loss_usd": number or null, "summary": <=220 chars, "actor": <=80 chars or "Unknown", "actor_type" ("product" for Chatbot harm, with the company and product as "actor"): "state"|"criminal"|"insider"|"researcher"|"hacktivist"|"accident"|"autonomous-ai"|"product"|"unknown", "sector": sector of the victim, one of "Financial services"|"Government & public sector"|"Technology & AI vendors"|"Healthcare"|"Media & entertainment"|"Retail & consumer brands"|"Education & research"|"Energy, industrial & infrastructure"|"Defence & security"|"Politics & elections"|"Individuals & consumers"|"Multiple / cross-sector"|"Unknown", "attribution": <=200 chars, "motive": <=160 chars, "vector": <=200 chars, "root_cause": <=220 chars, "impact": <=260 chars, "response": <=260 chars, "status": "resolved"|"patched"|"contained"|"ongoing"|"under investigation"|"unresolved", "cve": string or null, "young_people": true if a person under 25 was harmed or involved, else false, "setting": "school"|"university"|"home"|"online" or null (where it happened, for cases involving students or young people), "age_group": "child" (under 13)|"teen" (13-17)|"young-adult" (18-24) or null; never name a minor, "confidence": 0.0-1.0 (how sure you are this is a real, distinct, correctly summarised AI security incident based ONLY on the headline and summary)}
    Use only facts in the headline and summary; write "Unknown" where the text does not say. Never invent numbers. For Chatbot harm, write every claim as alleged unless a court has ruled, name the source of each allegation, and never describe methods of self-harm.

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
      break if e.message.include?("credit balance") # every other batch would fail the same way
    end
  end
  begin
    raise "all #{batches_failed} batches failed: #{sample}" if batches_ok == 0
    kept = []
    fresh.each_with_index do |w, n|
      v = by_i[n]
      triaged[w["id"]] = now.strftime("%Y-%m-%d") if v
      next unless v && v["keep"]
      w["kind"] = v["kind"]; w["tag"] = v["tag"]; w["one_line"] = v["one_line"]; w["sector"] = v["sector"] if v["sector"]
      if v["kind"] == "warning" && v["warning"].is_a?(Hash)
        wd = v["warning"]
        warnings_new << { "id" => w["id"], "date" => w["published"].to_s[0, 10], "sectors" => Array(wd["sectors"]).first(4), "who" => wd["who"].to_s[0, 80], "who_type" => wd["who_type"], "country" => wd["country"], "kind" => wd["type"],
                          "title" => wd["title"].to_s[0, 120], "summary" => wd["summary"].to_s[0, 280], "url" => w["url"], "source" => w["source"], "lang" => w["lang"], "added_at" => now.iso8601, "origin" => "robot" }
      end
      if v["new_incident"] && v["draft"].is_a?(Hash)
        d = v["draft"]
        d["id"] = d["id"].to_s.downcase.gsub(/[^a-z0-9-]+/, "-").gsub(/^-|-$/, "")[0, 40]
        d["id"] = "#{d['id']}-#{w['id'][0, 4]}" if (incidents + candidates).any? { |x| x["id"] == d["id"] }
        d["source"] = w["source"]; d["url"] = w["url"]
        d["sources"] = [{ "name" => w["source"], "url" => w["url"] }]
        d["timeline"] = [{ "date" => d["date"], "event" => "Reported by #{w['source']}" }]
        d["verified"] = false; d["drafted_at"] = now.iso8601; d["wire_id"] = w["id"]
        d["first_seen"] = w["seen"]; d["first_published"] = w["published"]; d["updated_at"] = now.iso8601
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
  inc = c.reject { |k, _| %w[verified wire_id confidence first_published].include?(k) }
  inc["verified_at"] = now.iso8601; inc["updated_at"] = now.iso8601
  inc["verification"] ||= "reported"
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
File.write(TRIAGED_PATH, JSON.generate(triaged))
warn_path = File.join(DATA, "warnings.json")
warnings = (JSON.parse(File.read(warn_path)) rescue [])
warnings = [] unless warnings.is_a?(Array)
seed_path = File.join(ROOT, "config", "warnings_seed.json")
seed = (JSON.parse(File.read(seed_path)) rescue [])
seen_urls = warnings.map { |x| x["url"] }
(seed + warnings_new).each { |x| next if x["url"].to_s.empty? || seen_urls.include?(x["url"]); warnings << x; seen_urls << x["url"] }
cutoff_w = (now - 400 * 86_400).strftime("%Y-%m-%d")
warnings = warnings.select { |x| x["date"].to_s >= cutoff_w }.sort_by { |x| [x["date"].to_s, x["title"].to_s] }.reverse
File.write(warn_path, JSON.pretty_generate(warnings))
log "warnings: #{warnings.size} in archive, #{warnings_new.size} new this run"
# Wire pulse: how many stories of each kind were published per day (by publication date, The wire itself only
# not discovery date). The wire itself only keeps KEEP_DAYS, so the Patterns page reads
# this growing history instead. Days still
# covered by the wire are recomputed (late tagging), older days are kept as they were.
pulse_path = File.join(SITE, "data", "pulse.json")
pulse = (JSON.parse(File.read(pulse_path)) rescue {})
pulse = {} unless pulse.is_a?(Hash)
wire.group_by { |w| w["published"].to_s[0, 10] }.each do |day, items|
  next if day.empty? || day > now.strftime("%Y-%m-%d")
  pulse[day] = items.group_by { |w| (w["kind"] || "untagged").to_s }.map { |k, v| [k, v.size] }.sort.to_h
end
File.write(pulse_path, JSON.pretty_generate(pulse.sort.to_h))
File.write(INC_PATH, JSON.pretty_generate(incidents)) if promoted.any?
esc = ->(s) { s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;") }
rss_items = wire.first(60).map do |w|
  desc = [w["one_line"], w["summary"]].compact.reject(&:empty?).first.to_s
  "<item><title>#{esc.(w['title'])}</title><link>#{esc.(w['url'])}</link><guid isPermaLink=\"false\">#{w['id']}</guid><pubDate>#{Time.parse(w['published']).rfc2822}</pubDate><category>#{esc.(w['kind'] || 'untagged')}</category><description>#{esc.("#{w['source']}: #{desc}")}</description></item>"
end
File.write(File.join(SITE, "feed.xml"), %(<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>AI Threat Watch wire</title><link>https://aithreat.io/#wire</link><description>AI security headlines from vetted sources, refreshed every 30 minutes.</description><lastBuildDate>#{now.rfc2822}</lastBuildDate>#{rss_items.join}</channel></rss>))

# ---------- alert feeds ----------
SITE_URL = "https://aithreat.io"
def write_rss(path, title, desc, items)
  esc = ->(s) { s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;") }
  body = items.map { |i| "<item><title>#{esc.(i[:title])}</title><link>#{esc.(i[:link])}</link><guid isPermaLink=\"false\">#{esc.(i[:guid])}</guid><pubDate>#{i[:date].rfc2822}</pubDate>#{i[:category] ? "<category>#{esc.(i[:category])}</category>" : ''}<description>#{esc.(i[:desc])}</description></item>" }.join
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, %(<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>#{esc.(title)}</title><link>#{SITE_URL}/</link><description>#{esc.(desc)}</description><lastBuildDate>#{Time.now.utc.rfc2822}</lastBuildDate>#{body}</channel></rss>))
end
require "fileutils"
case_item = ->(i) { { title: "[#{i['severity'].to_s.upcase}] #{i['title']}", link: "#{SITE_URL}/cases/#{i['id']}/", guid: "case-#{i['id']}", date: (Time.parse(i['verified_at'] || i['date'].to_s + 'T12:00:00Z').utc rescue now), category: i["category"], desc: "#{i['summary']} Target: #{i['target']}. #{i['country']}. Verification: #{i['verification'] || 'confirmed'}." } }
draft_item = ->(c) { { title: "[DEVELOPING] #{c['title']}", link: "#{SITE_URL}/##{c['id']}", guid: "draft-#{c['id']}", date: (Time.parse(c['drafted_at']).utc rescue now), category: c["category"], desc: "Unverified, auto-drafted from #{c['source']}. #{c['summary']} Source: #{c['url']}" } }
wire_item = ->(w) { { title: w["title"], link: w["url"], guid: w["id"], date: (Time.parse(w["seen"] || w["published"]).utc rescue now), category: w["kind"], desc: "#{w['source']}: #{w['one_line'] || w['summary']}" } }
recent_cases = incidents.sort_by { |i| i["verified_at"] || i["date"] }.reverse
write_rss(File.join(SITE, "feeds", "critical.xml"), "AI Threat Watch: critical and high severity cases", "Verified case files rated critical or high.", recent_cases.select { |i| %w[critical high].include?(i["severity"]) }.first(50).map(&case_item))
write_rss(File.join(SITE, "feeds", "cases.xml"), "AI Threat Watch: all verified cases", "Every verified case file, newest first.", recent_cases.first(100).map(&case_item))
write_rss(File.join(SITE, "feeds", "threats.xml"), "AI Threat Watch: threats on the wire", "Headlines the robot classified as incidents or exploited flaws, refreshed every 30 minutes.", wire.select { |w| %w[incident vulnerability].include?(w["kind"]) }.first(80).map(&wire_item))
write_rss(File.join(SITE, "feeds", "drafts.xml"), "AI Threat Watch: developing (unverified drafts)", "Auto-drafted case files awaiting editorial review.", candidates.sort_by { |c| c["drafted_at"] }.reverse.first(50).map(&draft_item))
slug = ->(s) { s.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "") }
recent_cases.group_by { |i| i["category"] }.each { |cat, items| write_rss(File.join(SITE, "feeds", "category", "#{slug.(cat)}.xml"), "AI Threat Watch: #{cat}", "Verified case files in the category #{cat}.", items.first(50).map(&case_item)) }
recent_cases.group_by { |i| i["country"] }.each { |cc, items| write_rss(File.join(SITE, "feeds", "country", "#{cc}.xml"), "AI Threat Watch: #{cc}", "Verified case files located in #{cc}.", items.first(50).map(&case_item)) }
File.write(File.join(SITE, "feeds", "index.json"), JSON.pretty_generate({ "generated_at" => now.iso8601, "categories" => recent_cases.map { |i| i["category"] }.uniq.sort.map { |c| { "name" => c, "slug" => slug.(c), "count" => recent_cases.count { |i| i["category"] == c } } }, "countries" => recent_cases.map { |i| i["country"] }.uniq.sort.map { |c| { "code" => c, "count" => recent_cases.count { |i| i["country"] == c } } } }))

status = { "updated_at" => now.iso8601, "wire_items" => wire.size, "new_items" => fresh.size, "candidates" => candidates.size, "incidents" => incidents.size, "feeds_ok" => feeds_ok, "feeds_failed" => feeds_failed, "triage" => triage_note }
File.write(STATUS_PATH, JSON.pretty_generate(status))

# Health alarm: tell the owner on Telegram when the wire goes stale (triage down, or many
# sources failing) and again when it recovers. Only on a change of state, never every run.
begin
  bot, owner = ENV["TELEGRAM_BOT_TOKEN"].to_s.strip, ENV["TELEGRAM_OWNER_CHAT_ID"].to_s.strip
  unless bot.empty? || owner.empty?
    problems = []
    problems << "sorting is failing: #{triage_note.to_s[0, 160]}" if triage_note.to_s.start_with?("triage failed")
    problems << "#{feeds_failed.size} of #{feeds_ok.size + feeds_failed.size} sources failed: #{feeds_failed.first(6).join(', ')}" if feeds_failed.size >= 8
    alarm_path = File.join(DATA, "alarm.json")
    was = (JSON.parse(File.read(alarm_path)) rescue {})["problems"] || []
    if problems.any? != was.any?
      text = problems.any? ? "⚠️ AI Threat Watch needs attention\n\n• #{problems.join("\n• ")}\n\nThe site keeps the last good data until this is fixed." : "✅ AI Threat Watch is back to normal: sorting works and sources answer."
      uri = URI("https://api.telegram.org/bot#{bot}/sendMessage")
      Net::HTTP.post(uri, { chat_id: owner, text: text }.to_json, "Content-Type" => "application/json")
      log "alarm sent: #{problems.any? ? 'problem' : 'recovered'}"
    end
    File.write(alarm_path, JSON.generate({ "problems" => problems, "checked_at" => now.iso8601 }))
  end
rescue => e
  log "alarm failed: #{e.message}"
end
log status.to_json
