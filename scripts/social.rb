#!/usr/bin/env ruby
# frozen_string_literal: true
# Posts each newly verified case file to Bluesky, Mastodon, Telegram and X.
#
# Source: site/cases/feed.xml (English, newest first). State: config/social_posted.json,
# one list of posted case URLs per platform. A platform runs only when its secrets are set.
# The first time a platform runs it records every case already in the feed and posts
# nothing, so switching a platform on never floods it with the back catalogue.
# Runs after the site is deployed, so links unfurl to a live page.
#
# Secrets (environment):
#   BLUESKY_HANDLE, BLUESKY_APP_PASSWORD           (Settings > Privacy and security > App passwords)
#   MASTODON_INSTANCE, MASTODON_TOKEN              (e.g. https://infosec.exchange; token with write:statuses)
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID           (bot from @BotFather, admin of the channel; chat id like @aithreat)
#   X_API_KEY, X_API_SECRET, X_ACCESS_TOKEN, X_ACCESS_SECRET  (developer.x.com app with Read and write; optional X_DAILY_CAP)
#
# Usage: ruby scripts/social.rb             # post up to MAX_PER_RUN new cases per platform
#        ruby scripts/social.rb --dry-run   # print what would be posted, change nothing

require "json"
require "net/http"
require "uri"
require "cgi"
require "time"

ROOT = File.expand_path("..", __dir__)
FEED = File.join(ROOT, "site", "cases", "feed.xml")
STATE = File.join(ROOT, "config", "social_posted.json")
OG_IMAGE = File.join(ROOT, "site", "assets", "brand", "og-image.png")
MAX_PER_RUN = 3
DRY_RUN = ARGV.include?("--dry-run")

TAGS = {
  "Prompt injection" => "PromptInjection",
  "Agent hijack" => "AIAgents",
  "AI supply chain" => "SupplyChainSecurity",
  "AI-assisted malware" => "Malware",
  "State actor AI ops" => "ThreatIntel",
  "Model & data leak" => "DataLeak",
  "LLMjacking" => "LLMjacking",
  "Deepfake fraud" => "Deepfake",
  "AI phishing" => "Phishing",
  "Chatbot harm" => "AISafety",
  "Deepfake abuse" => "Deepfakes",
  "AI misfire" => "AISafety",
  "AI exam fraud" => "EdTech"
}.freeze
SEVERITIES = %w[critical high medium low].freeze
SEVERITY_MARK = { "critical" => "🔴", "high" => "🟠", "medium" => "🟡", "low" => "⚪" }.freeze

def cases_from_feed
  xml = File.read(FEED)
  xml.scan(%r{<item>(.*?)</item>}m).map do |(item)|
    field = ->(name) { item[%r{<#{name}>(.*?)</#{name}>}m, 1].to_s }
    cats = item.scan(%r{<category>(.*?)</category>}).flatten.map { |c| CGI.unescapeHTML(c) }
    {
      url: field.call("link"),
      title: CGI.unescapeHTML(field.call("title")),
      summary: CGI.unescapeHTML(field.call("description")),
      type: cats.find { |c| !SEVERITIES.include?(c) },
      severity: cats.find { |c| SEVERITIES.include?(c) }
    }
  end
end

def truncate(text, max)
  chars = text.grapheme_clusters
  return text if chars.size <= max
  chars.first(max - 1).join.sub(/\s+\S*\z/, "") + "…"
end

def hashtags(c)
  ["AISecurity", TAGS[c[:type]]].compact.uniq.map { |t| "##{t}" }
end

def headline(c)
  mark = SEVERITY_MARK[c[:severity]]
  label = [c[:type], c[:severity] && "#{c[:severity]} severity"].compact.join(" · ")
  [mark, label].compact.join(" ")
end

def http_json(method, url, body: nil, headers: {}, raw: nil, content_type: "application/json")
  uri = URI(url)
  req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri)
  headers.each { |k, v| req[k] = v }
  if raw
    req["Content-Type"] = content_type
    req.body = raw
  elsif body
    req["Content-Type"] = "application/json; charset=utf-8"
    req.body = JSON.generate(body)
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 30) do |http|
    http.request(req)
  end
  raise "HTTP #{res.code} from #{uri.host}: #{res.body.to_s[0, 300]}" unless res.is_a?(Net::HTTPSuccess)
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

# ---- Bluesky: text with clickable hashtags, plus a link card with the brand image.
class Bluesky
  API = "https://bsky.social/xrpc"

  def initialize
    @handle = ENV["BLUESKY_HANDLE"].to_s.strip
    @password = ENV["BLUESKY_APP_PASSWORD"].to_s.strip
  end

  def enabled?
    !@handle.empty? && !@password.empty?
  end

  def compose(c)
    tags = hashtags(c).join(" ")
    fixed = "#{headline(c)}\n\n\n\n#{tags}"
    title = truncate(c[:title], 300 - fixed.grapheme_clusters.size)
    "#{headline(c)}\n\n#{title}\n\n#{tags}"
  end

  def post(c)
    @session ||= http_json(:post, "#{API}/com.atproto.server.createSession",
                           body: { identifier: @handle, password: @password })
    auth = { "Authorization" => "Bearer #{@session['accessJwt']}" }
    @thumb ||= http_json(:post, "#{API}/com.atproto.repo.uploadBlob", headers: auth,
                         raw: File.binread(OG_IMAGE), content_type: "image/png")["blob"]
    text = compose(c)
    record = {
      "$type" => "app.bsky.feed.post",
      text: text,
      createdAt: Time.now.utc.iso8601(3),
      langs: ["en"],
      facets: tag_facets(text),
      embed: {
        "$type" => "app.bsky.embed.external",
        external: { uri: c[:url], title: c[:title], description: truncate(c[:summary], 300), thumb: @thumb }
      }
    }
    http_json(:post, "#{API}/com.atproto.repo.createRecord", headers: auth,
              body: { repo: @session["did"], collection: "app.bsky.feed.post", record: record })
  end

  # Facet offsets are UTF-8 byte positions.
  def tag_facets(text)
    facets = []
    text.scan(/#(\w+)/) do
      m = Regexp.last_match
      start = text[0...m.begin(0)].bytesize
      facets << {
        index: { byteStart: start, byteEnd: start + m[0].bytesize },
        features: [{ "$type" => "app.bsky.richtext.facet#tag", tag: m[1] }]
      }
    end
    facets
  end
end

# ---- Mastodon: plain status; the server builds the link card from the page's Open Graph tags.
class Mastodon
  def initialize
    @instance = ENV["MASTODON_INSTANCE"].to_s.strip.sub(%r{/+\z}, "")
    @token = ENV["MASTODON_TOKEN"].to_s.strip
  end

  def enabled?
    !@instance.empty? && !@token.empty?
  end

  def compose(c)
    tags = hashtags(c).join(" ")
    # Mastodon counts every link as 23 characters.
    fixed = "#{headline(c)}\n\n\n\n#{c[:url]}\n\n#{tags}".length - c[:url].length + 23
    body = truncate("#{c[:title]}\n\n#{c[:summary]}", 500 - fixed)
    "#{headline(c)}\n\n#{body}\n\n#{c[:url]}\n\n#{tags}"
  end

  def post(c)
    http_json(:post, "#{@instance}/api/v1/statuses",
              headers: { "Authorization" => "Bearer #{@token}", "Idempotency-Key" => c[:url] },
              body: { status: compose(c), visibility: "public", language: "en" })
  end
end

# ---- Telegram: channel message with the link preview shown.
class Telegram
  def initialize
    @token = ENV["TELEGRAM_BOT_TOKEN"].to_s.strip
    @chat = ENV["TELEGRAM_CHAT_ID"].to_s.strip
  end

  def enabled?
    !@token.empty? && !@chat.empty?
  end

  def compose(c)
    h = ->(s) { CGI.escapeHTML(s) }
    "#{h.call(headline(c))}\n\n<b>#{h.call(c[:title])}</b>\n\n#{h.call(truncate(c[:summary], 600))}\n\n" \
      "<a href=\"#{h.call(c[:url])}\">Read the case file</a>\n#{hashtags(c).join(' ')}"
  end

  def post(c)
    # The Share button sends the case with a credit to the channel, so every share is an invitation.
    share = "https://t.me/share/url?url=#{CGI.escape(c[:url])}&text=#{CGI.escape("#{c[:title]} (via t.me/aithreat)")}"
    http_json(:post, "https://api.telegram.org/bot#{@token}/sendMessage",
              body: { chat_id: @chat, text: compose(c), parse_mode: "HTML",
                      link_preview_options: { url: c[:url], prefer_large_media: true },
                      reply_markup: { inline_keyboard: [[{ text: "Read the case file", url: c[:url] },
                                                         { text: "Share", url: share }]] } })
  end
end

# ---- X: one post per case, link last so X builds the card from the page's Open Graph tags.
# Signed with OAuth 1.0a (user context), which X requires for posting. X's API tiers cap
# monthly posts, so this client also keeps a rolling 24-hour cap (X_DAILY_CAP).
class XPost
  API = "https://api.x.com/2/tweets"
  DAILY_CAP = (ENV["X_DAILY_CAP"] || 12).to_i

  def initialize
    @key = ENV["X_API_KEY"].to_s.strip
    @secret = ENV["X_API_SECRET"].to_s.strip
    @token = ENV["X_ACCESS_TOKEN"].to_s.strip
    @token_secret = ENV["X_ACCESS_SECRET"].to_s.strip
  end

  def enabled?
    [@key, @secret, @token, @token_secret].none?(&:empty?)
  end

  # X counts every link as 23 characters and most emoji as 2.
  def compose(c)
    tags = hashtags(c).join(" ")
    fixed = "#{headline(c)}\n\n\n\n#{tags}\n\n".length + 23 + 2
    "#{headline(c)}\n\n#{truncate(c[:title], 280 - fixed)}\n\n#{tags}\n\n#{c[:url]}"
  end

  def post(c)
    require "openssl"
    require "base64"
    require "securerandom"
    enc = ->(s) { s.to_s.b.gsub(/[^A-Za-z0-9\-._~]/n) { |ch| format("%%%02X", ch.ord) } }
    oauth = {
      "oauth_consumer_key" => @key, "oauth_nonce" => SecureRandom.hex(16),
      "oauth_signature_method" => "HMAC-SHA1", "oauth_timestamp" => Time.now.to_i.to_s,
      "oauth_token" => @token, "oauth_version" => "1.0"
    }
    params = oauth.sort.map { |k, v| "#{enc.call(k)}=#{enc.call(v)}" }.join("&")
    base = ["POST", enc.call(API), enc.call(params)].join("&")
    signing_key = "#{enc.call(@secret)}&#{enc.call(@token_secret)}"
    oauth["oauth_signature"] = Base64.strict_encode64(OpenSSL::HMAC.digest("sha1", signing_key, base))
    header = "OAuth " + oauth.sort.map { |k, v| %(#{enc.call(k)}="#{enc.call(v)}") }.join(", ")
    http_json(:post, API, headers: { "Authorization" => header }, body: { text: compose(c) })
  end
end

# ---- X by hand: X's API charges per post, so instead the robot sends the owner, once a
# day, a ready-to-paste X post for the most severe new case, on Telegram, with a button
# that opens X with the text filled in. Posting through x.com/intent is free.
# Needs TELEGRAM_BOT_TOKEN and TELEGRAM_OWNER_CHAT_ID (the owner's own numeric chat id;
# the owner must have pressed Start on the bot once).
class XDraft
  DAILY_CAP = 1
  HOURS_UTC = (6..19).freeze # drafts arrive during the day, not at night

  def initialize
    @token = ENV["TELEGRAM_BOT_TOKEN"].to_s.strip
    @chat = ENV["TELEGRAM_OWNER_CHAT_ID"].to_s.strip
  end

  def enabled?
    !@token.empty? && !@chat.empty? && HOURS_UTC.cover?(Time.now.utc.hour)
  end

  def compose(c)
    XPost.new.compose(c)
  end

  def post(c)
    text = compose(c)
    intent = "https://x.com/intent/post?text=#{CGI.escape(text)}"
    msg = "📣 <b>Today’s X post for @aithreat</b>\n\nTap the text to copy it, or press the button to open X with it filled in.\n\n<code>#{CGI.escapeHTML(text)}</code>"
    http_json(:post, "https://api.telegram.org/bot#{@token}/sendMessage",
              body: { chat_id: @chat, text: msg, parse_mode: "HTML", link_preview_options: { is_disabled: true },
                      reply_markup: { inline_keyboard: [[{ text: "Post on X", url: intent }, { text: "Open the case", url: c[:url] }]] } })
  end
end

# ---- Main
state = File.exist?(STATE) ? JSON.parse(File.read(STATE)) : {}
# Newest by verification, not by incident date: a case approved today about an incident
# from July is news for the channel, but it sits too far down the feed (which is ordered
# by incident date) to be seen there.
def cases_by_verification
  inc = JSON.parse(File.read(File.join(ROOT, "site", "data", "incidents.en.json")))
  inc.select { |i| i["verified"] != false && i["verified_at"] }
     .sort_by { |i| i["verified_at"] }.reverse.first(50)
     .map { |i| { url: "https://aithreat.io/cases/#{i['id']}/", title: i["title"].to_s, summary: i["summary"].to_s, type: i["category"], severity: i["severity"] } }
rescue StandardError
  []
end
cases = cases_by_verification
cases = cases_from_feed if cases.empty?
abort "social: no cases in #{FEED}" if cases.empty?
platforms = { "bluesky" => Bluesky.new, "mastodon" => Mastodon.new, "telegram" => Telegram.new, "x" => (ENV["X_USE_API"] == "1" ? XPost.new : XDraft.new) }

platforms.each do |name, client|
  unless client.enabled? || DRY_RUN
    puts "social: #{name} skipped (no secrets)"
    next
  end

  if !state.key?(name) && !DRY_RUN
    state[name] = cases.map { |c| c[:url] }
    puts "social: #{name} first run, recorded #{cases.size} existing cases, posted nothing"
    next
  end

  posted = state[name] || []
  # Oldest first, so a backlog goes out in the order the cases were published.
  fresh = cases.reject { |c| posted.include?(c[:url]) }.reverse.first(MAX_PER_RUN)
  # The daily X draft is the most severe case not yet drafted, newest first among equals.
  if client.is_a?(XDraft)
    fresh = cases.each_with_index.reject { |c, _| posted.include?(c[:url]) }
                 .sort_by { |c, i| [SEVERITIES.index(c[:severity]) || 9, i] }.map(&:first).first(1)
  end
  fresh = cases.first(1) if DRY_RUN && fresh.empty?
  # X: rolling 24-hour cap, so a burst of new cases cannot exhaust the monthly API quota.
  sent_log = (state["#{name}_sent_at"] || []).select { |t| Time.parse(t) > Time.now - 86_400 }
  fresh = fresh.first([client.class::DAILY_CAP - sent_log.size, 0].max) if client.class.const_defined?(:DAILY_CAP)
  fresh.each do |c|
    if DRY_RUN
      puts "---- #{name} (#{c[:url]})\n#{client.compose(c)}\n\n"
      next
    end
    begin
      client.post(c)
      posted << c[:url]
      sent_log << Time.now.utc.iso8601
      puts "social: #{name} posted #{c[:url]}"
      sleep 2
    rescue StandardError => e
      warn "social: #{name} failed on #{c[:url]}: #{e.message}"
      break
    end
  end
  # Keep the list bounded; the feed only carries the newest 50 cases.
  state[name] = posted.last(500)
  state["#{name}_sent_at"] = sent_log if client.class.const_defined?(:DAILY_CAP)
end

File.write(STATE, JSON.pretty_generate(state) + "\n") unless DRY_RUN
