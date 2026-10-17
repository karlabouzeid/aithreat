#!/usr/bin/env ruby
# frozen_string_literal: true
# Translates verified case files into every site language, so a newly approved case is
# not English-only. Runs in the robot after update.rb and before build_pages.rb.
#
# A case is (re)translated into a language when it is missing from site/i18n/<lang>.json
# or when its English text changed since it was last translated (site/i18n/_source.json
# keeps a fingerprint of the English each translation was made from). Translations done
# by hand before this script existed are adopted as they are: their fingerprint is taken
# from today's English on the first run, so they are not redone.
#
# Bounded: at most MAX_CASES cases per language per run, BATCH cases per API call.
# Usage: ruby scripts/translate.rb            # translate what is missing
#        ruby scripts/translate.rb --dry-run  # list what would be translated

require "json"
require "net/http"
require "uri"
require "digest"

ROOT = File.expand_path("..", __dir__)
I18N = File.join(ROOT, "site", "i18n")
INC_PATH = File.join(ROOT, "site", "data", "incidents.en.json")
SOURCE_PATH = File.join(I18N, "_source.json")
MODEL = ENV.fetch("ATW_MODEL", "claude-sonnet-5-5")
MAX_CASES = (ENV["TRANSLATE_MAX"] || 12).to_i
BATCH = 4
DRY_RUN = ARGV.include?("--dry-run")
FIELDS = %w[title summary target actor attribution motive vector root_cause impact response].freeze

STYLE = {
  "fr" => "French, in the register of French cybersecurity press and CERT-FR bulletins. French typography (space before : ; ? !), money as \"600 000 $\", « » for quotes.",
  "es" => "neutral international Spanish, cybersecurity press register. Money as \"600.000 USD\", “ ” for quotes.",
  "ar" => "Modern Standard Arabic as used by professional cybersecurity press and national CERTs. Money as \"600 ألف دولار\".",
  "zh" => "Simplified Chinese as used by FreeBuf and CERT bulletins, full-width punctuation; well-known companies may take their usual Chinese name with the English in brackets on first use. Money as \"60 万美元\".",
  "ru" => "Russian in the register of Хабр and Kaspersky Securelist. Money as \"600 000 долларов\", «ёлочки» for quotes; well-known public figures in their usual Russian spelling."
}.freeze

def log(msg)
  puts "[translate] #{msg}"
end

def source_of(i)
  { "id" => i["id"] }.merge(FIELDS.to_h { |f| [f, i[f]] }).merge("timeline" => (i["timeline"] || []).map { |e| e["event"] })
end

def fingerprint(src)
  Digest::SHA256.hexdigest(JSON.generate(src.reject { |k, _| k == "id" }))[0, 16]
end

def call_claude(api_key, prompt)
  uri = URI("https://api.anthropic.com/v1/messages")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 240
  req = Net::HTTP::Post.new(uri.path, "content-type" => "application/json", "x-api-key" => api_key, "anthropic-version" => "2023-06-01")
  req.body = { model: MODEL, max_tokens: 16_000, messages: [{ role: "user", content: prompt }] }.to_json
  res = http.request(req)
  raise "API #{res.code}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
  text = JSON.parse(res.body)["content"].map { |c| c["text"] }.join
  JSON.parse(text[/\[.*\]/m] || raise("no JSON array in reply"))
end

def valid?(src, out)
  out.is_a?(Hash) && out["id"] == src["id"] && FIELDS.all? { |f| out.key?(f) } &&
    out["timeline"].is_a?(Array) && out["timeline"].size == src["timeline"].size &&
    FIELDS.all? { |f| src[f].nil? || (out[f].is_a?(String) && !out[f].strip.empty?) }
end

api_key = ENV["ANTHROPIC_API_KEY"].to_s.strip
abort "[translate] no ANTHROPIC_API_KEY, skipping" if api_key.empty? && !DRY_RUN

langs = Dir[File.join(I18N, "*.json")].map { |p| File.basename(p, ".json") }.reject { |l| l.start_with?("_") }.sort
cases = JSON.parse(File.read(INC_PATH)).reject { |i| i["verified"] == false }
sources = cases.to_h { |i| s = source_of(i); [i["id"], s] }
prints = (JSON.parse(File.read(SOURCE_PATH)) rescue {})
prints = {} unless prints.is_a?(Hash)

langs.each do |lang|
  path = File.join(I18N, "#{lang}.json")
  entries = JSON.parse(File.read(path))
  have = entries.to_h { |e| [e["id"], e] }
  fp = (prints[lang] ||= {})
  # Adopt translations that predate this script: fingerprint today's English, do not redo.
  have.each_key { |id| fp[id] ||= fingerprint(sources[id]) if sources[id] }
  todo = sources.values.select { |s| !have.key?(s["id"]) || fp[s["id"]] != fingerprint(s) }.first(MAX_CASES)
  log "#{lang}: #{todo.size} to translate (#{have.size} present)"
  next if todo.empty? || DRY_RUN

  done = 0
  todo.each_slice(BATCH) do |batch|
    prompt = <<~P
      Translate these AI-security case files from English into #{STYLE.fetch(lang, lang)}
      Keep product, company, CVE, malware, researcher and vendor names, tickers and URLs in Latin script.
      Do not summarise, shorten or add facts. Never put a straight double quote character inside a string value.
      Return ONLY a JSON array with one object per input object, same order, with exactly these keys:
      "id" (unchanged), #{FIELDS.map { |f| %("#{f}") }.join(', ')}, "timeline" (array of strings, same length and order as the input).
      Keep null values as null.

      #{JSON.pretty_generate(batch)}
    P
    begin
      out = call_claude(api_key, prompt)
      batch.each_with_index do |src, n|
        t = out[n]
        unless valid?(src, t)
          log "#{lang}: rejected malformed translation for #{src['id']}"
          next
        end
        have[src["id"]] = FIELDS.to_h { |f| [f, t[f]] }.merge("id" => src["id"], "timeline" => t["timeline"])
        fp[src["id"]] = fingerprint(src)
        done += 1
      end
    rescue => e
      log "#{lang}: batch failed: #{e.message[0, 200]}"
      break if e.message.include?("credit balance")
    end
  end
  # Keep the file's existing order (small diffs): replace in place, append new cases.
  merged = entries.map { |e| have[e["id"]] || e }
  merged += have.values.reject { |e| entries.any? { |x| x["id"] == e["id"] } }
  File.write(path, JSON.pretty_generate(merged) + "\n")
  log "#{lang}: translated #{done}"
end

File.write(SOURCE_PATH, JSON.pretty_generate(prints) + "\n") unless DRY_RUN
