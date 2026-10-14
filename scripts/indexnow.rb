#!/usr/bin/env ruby
# frozen_string_literal: true
# Tells Bing (and every other IndexNow engine: Yandex, Seznam, Naver, Yep)
# which pages changed in the last commit, so new or edited case files are
# picked up within minutes instead of weeks. Google does not use IndexNow;
# it re-reads sitemap.xml on its own schedule.
#
# The key is a random string that must also be served at https://aithreat.io/<key>.txt
# (that file lives in site/). It is not a secret.
#
# Usage: ruby scripts/indexnow.rb            # URLs from `git diff HEAD~1 HEAD`
#        ruby scripts/indexnow.rb --all      # every page in sitemap.xml (use once after launch)

require "json"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
SITE = File.join(ROOT, "site")
HOST = "aithreat.io"

key_file = Dir.glob(File.join(SITE, "*.txt")).find { |f| File.basename(f) =~ /\A[0-9a-f]{32}\.txt\z/ }
abort "indexnow: no key file in site/ (expected <32 hex chars>.txt)" unless key_file
key = File.basename(key_file, ".txt")

urls =
  if ARGV.include?("--all")
    File.read(File.join(SITE, "sitemap.xml")).scan(%r{<loc>([^<]+)</loc>}).flatten
  else
    changed = `git -C #{ROOT} diff --name-only HEAD~1 HEAD 2>/dev/null`.lines.map(&:strip)
    changed.map do |p|
      case p
      when %r{\Asite/((?:fr|es|ar|zh)/)?cases/(.*/)?index\.html\z} then "https://#{HOST}/#{$1}cases/#{$2}"
      when %r{\Asite/index\.html\z} then "https://#{HOST}/"
      when %r{\Asite/((?:fr|es|ar|zh)/)?cases/feed\.xml\z} then "https://#{HOST}/#{$1}cases/feed.xml"
      end
    end.compact
  end.uniq

if urls.empty?
  puts "indexnow: nothing changed, nothing to submit"
  exit 0
end

urls.each_slice(10_000) do |batch|
  body = { host: HOST, key: key, keyLocation: "https://#{HOST}/#{key}.txt", urlList: batch }
  uri = URI("https://api.indexnow.org/indexnow")
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
    req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json; charset=utf-8")
    req.body = JSON.generate(body)
    http.request(req)
  end
  puts "indexnow: submitted #{batch.size} urls, HTTP #{res.code} #{res.message}"
end
