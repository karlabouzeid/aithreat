#!/usr/bin/env ruby
# frozen_string_literal: true
# Copies the homepage labels (home_strings.rb) and the i_* / u_* explanations (info_strings.rb) into the
# UI table of site/index.html, between /*home:start*/ and /*home:end*/ in each language. Safe to re-run.
# Usage: ruby scripts/sync_home_strings.rb

require "json"
require_relative "home_strings"
require_relative "info_strings"

path = File.expand_path("../site/index.html", __dir__)
html = File.read(path, encoding: "UTF-8")
%w[en fr es ar zh ru].each do |lang|
  pairs = HOME[lang].merge(INFO[lang].select { |k, _| k.to_s.start_with?("i_", "u_", "f_") })
  block = "/*home:start*/ " + pairs.map { |k, v| "#{k}: #{JSON.generate(v)}" }.join(", ") + ", /*home:end*/ "
  head = "\n    #{lang}: { "
  at = html.index(head) or abort "no UI table for #{lang}"
  start = at + head.size
  if html[start, 14] == "/*home:start*/"
    stop = html.index("/*home:end*/ ", start) or abort "unclosed block for #{lang}"
    html[start...(stop + "/*home:end*/ ".size)] = block
  else
    html.insert(start, block)
  end
end
File.write(path, html)
puts "sync_home_strings: #{HOME['en'].size} labels and #{INFO['en'].keys.count { |k| k.to_s.start_with?('i_', 'u_', 'f_') }} explanations in 6 languages"
