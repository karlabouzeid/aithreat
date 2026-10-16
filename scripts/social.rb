#!/usr/bin/env ruby
# frozen_string_literal: true
# Posts each newly verified case file to Bluesky, Mastodon and Telegram.
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
  "AI phishing" => "Phishing"
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
    @handle = ENV["BLUESKY_HANDLE"].to_s
    @password = ENV["BLUESKY_APP_PASSWORD"].to_s
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
    @instance = ENV["MASTODON_INSTANCE"].to_s.sub(%r{/+\z}, "")
    @token = ENV["MASTODON_TOKEN"].to_s
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
    @token = ENV["TELEGRAM_BOT_TOKEN"].to_s
    @chat = ENV["TELEGRAM_CHAT_ID"].to_s
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
    http_json(:post, "https://api.telegram.org/bot#{@token}/sendMessage",
              body: { chat_id: @chat, text: compose(c), parse_mode: "HTML",
                      link_preview_options: { url: c[:url], prefer_large_media: true } })
  end
end

# ---- Main
state = File.exist?(STATE) ? JSON.parse(File.read(STATE)) : {}
cases = cases_from_feed
abort "social: no cases in #{FEED}" if cases.empty?
platforms = { "bluesky" => Bluesky.new, "mastodon" => Mastodon.new, "telegram" => Telegram.new }

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
  fresh = cases.first(1) if DRY_RUN && fresh.empty?
  fresh.each do |c|
    if DRY_RUN
      puts "---- #{name} (#{c[:url]})\n#{client.compose(c)}\n\n"
      next
    end
    begin
      client.post(c)
      posted << c[:url]
      puts "social: #{name} posted #{c[:url]}"
      sleep 2
    rescue StandardError => e
      warn "social: #{name} failed on #{c[:url]}: #{e.message}"
      break
    end
  end
  # Keep the list bounded; the feed only carries the newest 50 cases.
  state[name] = posted.last(500)
end

File.write(STATE, JSON.pretty_generate(state) + "\n") unless DRY_RUN
