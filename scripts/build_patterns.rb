# Patterns page: trends and statistics computed from the verified case files, drawn as
# inline SVG (no chart library, no JavaScript), with editorial captions whose numbers are
# filled in at build time. Loaded by build_pages.rb after its own pages; expects its
# helpers (head, shell, x, t, tt, pre, h, fmt_usd, lang_links, crumbs_*) and `incidents`.
# Also writes site/data/stats.json so the numbers can be reused without scraping.

require "time"
TREND_FROM = "2025-01-01"
SEV_ORDER = %w[critical high medium low].freeze
CAT_COLORS = %w[#f5b942 #5b9cff #ff5d62 #4fd1a1 #c084fc #ff9a4c #8b9bb1 #38bdf8 #e879a6].freeze
KIND_COLORS = { "research" => "#5b9cff", "vulnerability" => "#ff9a4c", "incident" => "#ff5d62", "vendor-report" => "#4fd1a1", "policy" => "#c084fc", "other" => "#8b9bb1", "untagged" => "#3a4760" }.freeze
SEV_COLORS = { "critical" => "var(--crit)", "high" => "var(--high)", "medium" => "var(--med)", "low" => "var(--low)" }.freeze

PATTERNS_CSS = <<~CSS
  .kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:0 0 20px}
  .kpis div{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:14px 16px}
  .kpis b{display:block;font:700 30px/1 var(--f-display);letter-spacing:-.01em;margin:0 0 6px}.kpis span{font:12px var(--f-mono);color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
  html[lang="ar"] .kpis span,html[lang="zh"] .kpis span{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  .kpis small{display:block;color:var(--muted);font-size:12px;margin-top:4px}
  .chart{width:100%;height:auto;display:block;margin:6px 0 10px;font:11px var(--f-mono);fill:var(--muted)}
  .chart .ax{stroke:var(--line2);stroke-width:1}.chart .grid{stroke:var(--line);stroke-width:1}.chart .lbl{fill:var(--muted)}.chart .val{fill:var(--ink);font-weight:600}
  .legend{display:flex;flex-wrap:wrap;gap:6px 16px;font:12px var(--f-mono);color:var(--muted);margin:0 0 6px}.legend i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-inline-end:6px;vertical-align:-1px}
  .cap{color:var(--muted);max-width:80ch;margin:0}
  table.pt{width:100%;border-collapse:collapse;font-size:14px;margin:6px 0 10px}table.pt th,table.pt td{text-align:start;padding:6px 8px;border-bottom:1px solid var(--line)}table.pt th{font:600 11px var(--f-mono);text-transform:uppercase;letter-spacing:.05em;color:var(--muted)}table.pt td.n{font-family:var(--f-mono);text-align:end}
  html[lang="ar"] table.pt th,html[lang="zh"] table.pt th{font-family:var(--f-body);text-transform:none}
  .bars{display:grid;gap:6px;margin:6px 0 10px}.bars div{display:grid;grid-template-columns:minmax(120px,38%) 1fr 44px;gap:10px;align-items:center;font-size:13px}.bars i{display:block;height:12px;border-radius:3px;background:var(--accent);min-width:2px}.bars em{font:12px var(--f-mono);color:var(--muted);font-style:normal;text-align:end}
  .method{font-size:12px;color:var(--muted);background:var(--surface);border:1px dashed var(--line2);border-radius:8px;padding:10px 12px;margin:18px 0}
  ul.cases.auto li{grid-template-columns:96px 1fr}
  h2.fin-h{font-size:clamp(22px,3vw,28px);margin:28px 0 6px;scroll-margin-top:16px}
CSS

def quarter_of(d)
  y = d[0, 4]; m = d[5, 2].to_i
  "#{y}-Q#{(m - 1) / 3 + 1}"
end

def half_of(d)
  "#{d[0, 4]}#{d[5, 2].to_i <= 6 ? 'H1' : 'H2'}"
end

def quarters_between(from, to)
  qs = []
  y, q = from[0, 4].to_i, from[6].to_i
  ty, tq = to[0, 4].to_i, to[6].to_i
  while y < ty || (y == ty && q <= tq)
    qs << "#{y}-Q#{q}"
    q += 1
    if q > 4 then q = 1; y += 1 end
  end
  qs
end

def pct(a, b)
  b.to_i.zero? ? 0 : (100.0 * a / b).round
end

def fmt_money_short(v)
  return "$0" if v.to_f <= 0
  v >= 1e9 ? "$#{(v / 1e9).round(1)}B" : v >= 1e6 ? "$#{(v / 1e6).round(v >= 1e8 ? 0 : 1)}M" : "$#{(v / 1e3).round}K"
end

def svg_wrap(w, hgt, inner, label)
  %(<svg class="chart" viewBox="0 0 #{w} #{hgt}" role="img" aria-label="#{h(label)}" xmlns="http://www.w3.org/2000/svg">#{inner}</svg>)
end

# Stacked vertical bars. series: [[name, color, [values per column]]...]; cols: labels.
def stacked_bars(cols, series, label, w: 760, hgt: 260, ltr: true)
  pad_l, pad_r, pad_t, pad_b = 36, 10, 10, 34
  n = cols.size
  totals = (0...n).map { |i| series.sum { |s| s[2][i].to_f } }
  max = [totals.max.to_f, 1].max
  step = max <= 10 ? 2 : max <= 30 ? 5 : max <= 60 ? 10 : 20
  top = ((max / step).ceil * step).to_f
  cw = (w - pad_l - pad_r).to_f / n
  bw = [cw * 0.62, 48].min
  ph = hgt - pad_t - pad_b
  out = +""
  (0..(top / step)).each do |k|
    y = pad_t + ph - ph * (k * step / top)
    out << %(<line class="grid" x1="#{pad_l}" x2="#{w - pad_r}" y1="#{y.round(1)}" y2="#{y.round(1)}"/><text class="lbl" x="#{pad_l - 6}" y="#{(y + 4).round(1)}" text-anchor="end">#{(k * step).to_i}</text>)
  end
  (0...n).each do |i|
    x = pad_l + cw * i + (cw - bw) / 2
    y = pad_t + ph
    series.each do |name, color, vals|
      v = vals[i].to_f
      next if v <= 0
      bh = ph * v / top
      y -= bh
      out << %(<rect x="#{x.round(1)}" y="#{y.round(1)}" width="#{bw.round(1)}" height="#{bh.round(1)}" rx="2" style="fill:#{color}"><title>#{h(name)}: #{v.to_i}</title></rect>)
    end
    out << %(<text class="val" x="#{(x + bw / 2).round(1)}" y="#{(y - 4).round(1)}" text-anchor="middle">#{totals[i].to_i}</text>) if totals[i] > 0
    out << %(<text class="lbl" x="#{(x + bw / 2).round(1)}" y="#{hgt - 12}" text-anchor="middle">#{h(cols[i])}</text>)
  end
  out << %(<line class="ax" x1="#{pad_l}" x2="#{w - pad_r}" y1="#{pad_t + ph}" y2="#{pad_t + ph}"/>)
  svg_wrap(w, hgt, out, label)
end

def legend(series)
  %(<div class="legend">#{series.map { |name, color, _| %(<span><i style="background:#{color}"></i>#{h(name)}</span>) }.join}</div>)
end

# Heat strip: rows × cols with counts, colour intensity by value.
def heat_grid(rows, cols, matrix, label, w: 760)
  pad_l = 190; cell_h = 26; cw = (w - pad_l - 8).to_f / cols.size; hgt = cell_h * rows.size + 30
  max = [matrix.flatten.max.to_i, 1].max
  out = +""
  cols.each_with_index { |c, j| out << %(<text class="lbl" x="#{(pad_l + cw * j + cw / 2).round(1)}" y="18" text-anchor="middle">#{h(c)}</text>) }
  rows.each_with_index do |r, i|
    y = 26 + cell_h * i
    out << %(<text class="lbl" x="#{pad_l - 8}" y="#{y + 17}" text-anchor="end">#{h(r.size > 26 ? r[0, 25] + '…' : r)}</text>)
    cols.each_index do |j|
      v = matrix[i][j].to_i
      a = v.zero? ? 0.06 : 0.18 + 0.82 * v / max
      out << %(<rect x="#{(pad_l + cw * j + 2).round(1)}" y="#{y + 2}" width="#{(cw - 4).round(1)}" height="#{cell_h - 4}" rx="4" style="fill:var(--accent);fill-opacity:#{a.round(2)}"><title>#{h(r)} · #{h(cols[j])}: #{v}</title></rect>)
      out << %(<text x="#{(pad_l + cw * j + cw / 2).round(1)}" y="#{y + 17}" text-anchor="middle" style="fill:#{a > 0.55 ? 'var(--accent-ink)' : 'var(--ink)'};font-weight:600">#{v}</text>) if v > 0
    end
  end
  svg_wrap(w, hgt, out, label)
end

def hbars(rows, fmt: ->(v) { v.to_s })
  max = [rows.map { |_, v| v.to_f }.max.to_f, 1].max
  %(<div class="bars">#{rows.map { |name, v| %(<div><span>#{h(name)}</span><i style="width:#{(100.0 * v / max).round(1)}%"></i><em>#{h(fmt.call(v))}</em></div>) }.join}</div>)
end

# AI products and platforms counted in the third-party risk table: display name => pattern
# matched against a case file's title, target, vector and summary.
AI_PRODUCTS = {
  "OpenAI / ChatGPT" => /\b(OpenAI|ChatGPT|Codex|GPT-[0-9o])/i, "Anthropic / Claude" => /\b(Anthropic|Claude)\b/i,
  "Google Gemini" => /\b(Gemini|Antigravity)\b/i, "Microsoft Copilot" => /\bCopilot\b/i, "Meta AI / Llama" => /\b(Meta AI|Llama)\b/,
  "xAI / Grok" => /\b(xAI|Grok)\b/, "DeepSeek" => /\bDeepSeek\b/i, "Cursor" => /\bCursor\b/, "Langflow" => /\bLangflow\b/i,
  "LiteLLM" => /\bLiteLLM\b/i, "MLflow" => /\bMLflow\b/i, "Ray (Anyscale)" => /\b(Ray|Anyscale|ShadowRay)\b/, "n8n" => /\bn8n\b/i,
  "Hugging Face" => /\bHugging ?Face\b/i, "MCP servers" => /\bMCP\b/, "OpenClaw" => /\bOpenClaw\b/i, "Ollama" => /\bOllama\b/i,
  "Replit" => /\bReplit\b/i, "Lovable" => /\bLovable\b/i, "Salesforce Agentforce" => /\b(Agentforce|Salesforce)\b/,
  "Amazon Q / Bedrock" => /\b(Amazon Q|Bedrock)\b/, "Slack AI" => /\bSlack AI\b/i
}.freeze

def patterns_stats(incidents, pulse)
  now = Time.now.utc
  today = now.strftime("%Y-%m-%d")
  all = incidents
  trend = all.select { |i| i["date"].to_s >= TREND_FROM }
  quarters = quarters_between(quarter_of(TREND_FROM), quarter_of(today))
  by_q = trend.group_by { |i| quarter_of(i["date"]) }
  cur_q = quarters.last; prev_q = quarters[-2]
  halves = trend.map { |i| half_of(i["date"]) }.uniq.sort
  halves.pop if halves.size > 2 && halves.last == half_of(today) # the current half-year is incomplete
  first_half = trend.select { |i| half_of(i["date"]) == halves.first }
  last_half = trend.select { |i| half_of(i["date"]) == halves.last }
  cats = all.map { |i| i["category"] }.group_by(&:itself).map { |k, v| [k, v.size] }.sort_by { |_, n| -n }
  cat_q = cats.map { |c, _| quarters.map { |q| (by_q[q] || []).count { |i| i["category"] == c } } }
  last4 = quarters.last(4); prev4 = quarters[-8, 4] || []
  growth = cats.each_with_index.map { |(c, _), i| l = last4.sum { |q| (by_q[q] || []).count { |x| x["category"] == c } }; p = prev4.sum { |q| (by_q[q] || []).count { |x| x["category"] == c } }; [c, l - p, l] }
  rising = growth.max_by { |_, d, l| [d, l] }
  auto = all.select { |i| i["actor_type"] == "autonomous-ai" }.sort_by { |i| i["date"] }
  years = all.map { |i| i["date"][0, 4] }.uniq.select { |y| y >= "2025" }.sort
  actor_types = %w[criminal state researcher unknown autonomous-ai accident hacktivist insider]
  actor_year = actor_types.map { |a| [a, years.map { |y| all.count { |i| i["date"][0, 4] == y && (i["actor_type"] || "unknown") == a } }] }
  losses = all.select { |i| i["loss_usd"].to_f > 0 }
  loss_total = losses.sum { |i| i["loss_usd"].to_f }
  loss_cat = cats.map { |c, _| [c, losses.select { |i| i["category"] == c }.sum { |i| i["loss_usd"].to_f }, losses.count { |i| i["category"] == c }] }
  deep = loss_cat.find { |c, _, _| c == "Deepfake fraud" }
  sectors = all.map { |i| i["sector"] || "Unknown" }.group_by(&:itself).map { |k, v| [k, v.size] }.sort_by { |_, n| -n }
  countries = all.map { |i| i["country"] || "GL" }.group_by(&:itself).map { |k, v| [k, v.size] }.sort_by { |_, n| -n }
  gl = countries.find { |c, _| c == "GL" }&.last.to_i
  statuses = all.map { |i| (i["status"] || "unknown").to_s.downcase }.group_by(&:itself).map { |k, v| [k, v.size] }.sort_by { |_, n| -n }
  unresolved = all.count { |i| %w[ongoing under\ investigation unresolved].include?(i["status"].to_s.downcase) }
  speeds = all.select { |i| i["drafted_at"] && i["verified_at"] }.map { |i| (Time.parse(i["verified_at"]) - Time.parse(i["drafted_at"])) / 3600.0 rescue nil }.compact.sort
  median_h = speeds.empty? ? nil : speeds[speeds.size / 2]
  pulse_days = pulse.keys.sort.last(28)
  kinds = %w[incident vulnerability research vendor-report policy other untagged]
fin = all.select { |i| i["sector"] == "Financial services" }
ind = all.select { |i| i["sector"] == "Individuals & consumers" }
vendors = AI_PRODUCTS.map do |name, re|
  hits = all.select { |i| [i["title"], i["target"], i["vector"], i["summary"]].join(" ") =~ re }
  { "product" => name, "n" => hits.size, "critical_high" => hits.count { |i| %w[critical high].include?(i["severity"]) },
    "with_cve" => hits.count { |i| i["cve"].to_s =~ /CVE-/ }, "latest" => hits.max_by { |i| i["date"].to_s }&.fetch("id") }
end.select { |v| v["n"] > 0 }.sort_by { |v| [-v["n"], v["product"]] }
{
  "generated_at" => now.iso8601, "total" => all.size, "trend_from" => TREND_FROM,
  "finance" => { "top_losses" => losses.sort_by { |i| -i["loss_usd"].to_f }.first(8).map { |i| i["id"] },
    "financial_services" => fin.size, "individuals" => ind.size,
    "fin_by_category" => fin.group_by { |i| i["category"] }.map { |k, v| [k, v.size] }.sort_by { |_, n| -n }.to_h,
    "fin_by_quarter" => quarters.map { |q| fin.count { |i| i["date"].to_s >= TREND_FROM && quarter_of(i["date"]) == q } },
    "fin_latest" => fin.sort_by { |i| i["date"].to_s }.reverse.first(5).map { |i| i["id"] }, "vendors" => vendors.first(15) },
    "this_quarter" => { "q" => cur_q, "n" => (by_q[cur_q] || []).size, "prev_q" => prev_q, "prev_n" => (by_q[prev_q] || []).size },
    "direction" => { "on-ai" => all.count { |i| i["direction"] == "on-ai" }, "with-ai" => all.count { |i| i["direction"] == "with-ai" } },
    "on_ai_share_first_half" => pct(first_half.count { |i| i["direction"] == "on-ai" }, first_half.size), "on_ai_share_last_half" => pct(last_half.count { |i| i["direction"] == "on-ai" }, last_half.size),
    "quarters" => quarters.map { |q| items = by_q[q] || []; { "q" => q, "n" => items.size, "on-ai" => items.count { |i| i["direction"] == "on-ai" }, "with-ai" => items.count { |i| i["direction"] == "with-ai" }, "severity" => SEV_ORDER.map { |s| [s, items.count { |i| i["severity"] == s }] }.to_h, "autonomous" => items.count { |i| i["actor_type"] == "autonomous-ai" }, "real_world" => items.count { |i| i["actor_type"] != "researcher" } } },
    "categories" => cats.each_with_index.map { |(c, n), i| { "category" => c, "n" => n, "by_quarter" => cat_q[i], "growth_last4_vs_prev4" => growth[i][1] } },
    "rising_category" => rising && rising[0], "top_category" => cats.first && cats.first[0], "top_category_n" => cats.first && cats.first[1],
    "autonomous" => { "by_year" => years.map { |y| [y, auto.count { |i| i["date"][0, 4] == y }] }.to_h, "ids" => auto.map { |i| i["id"] } },
    "actors" => actor_year.map { |a, vals| { "actor_type" => a, "by_year" => years.zip(vals).to_h, "n" => all.count { |i| (i["actor_type"] || "unknown") == a } } }, "years" => years,
    "severity" => SEV_ORDER.map { |s| [s, all.count { |i| i["severity"] == s }] }.to_h, "critical_high_pct" => pct(all.count { |i| %w[critical high].include?(i["severity"]) }, all.size),
    "losses" => { "total_usd" => loss_total.round, "disclosed" => losses.size, "by_category" => loss_cat.map { |c, v, n| { "category" => c, "usd" => v.round, "disclosed" => n } }, "deepfake_share_pct" => deep ? pct(deep[1], loss_total) : 0 },
    "sectors" => sectors.map { |s, n| { "sector" => s, "n" => n } },
    "countries" => countries.first(12).map { |c, n| { "country" => c, "n" => n } }, "global_pct" => pct(gl, all.size),
    "status" => statuses.map { |s, n| { "status" => s, "n" => n } }, "unresolved_pct" => pct(unresolved, all.size),
    "verify_median_hours" => median_h && median_h.round(1), "verify_sample" => speeds.size,
    "researcher_demos" => all.count { |i| i["actor_type"] == "researcher" },
    "pulse" => pulse_days.map { |d| { "day" => d, "kinds" => kinds.map { |k| [k, (pulse[d] || {})[k].to_i] }.to_h } }
  }
end

def patterns_page(lang, st, incidents)
  path = "#{pre(lang)}/patterns/"
  url = BASE + path
  alternates = Hash[LANGS.map { |l| [l, "#{BASE}#{pre(l)}/patterns/"] }]
  title = x(lang, :patterns_h)
  lede = x(lang, :patterns_lede)
  q = lang == "en" ? "" : "?lang=#{lang}"
  jsonld = [
    { "@context" => "https://schema.org", "@type" => "Dataset", "@id" => url, "name" => title, "description" => lede, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "creator" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "distribution" => [{ "@type" => "DataDownload", "encodingFormat" => "application/json", "contentUrl" => "#{BASE}/data/stats.json" }], "dateModified" => st["generated_at"][0, 10] },
    crumbs_ld(lang, [[x(lang, :patterns), url]])
  ]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: lede, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  headhtml = headhtml.sub("</style>", PATTERNS_CSS + "</style>")
  cat_name = ->(c) { tt(lang, "cats", c) }
  actor_name = ->(a) { tt(lang, "actor_types", a) }
  sev_name = ->(s) { tt(lang, "sev", s) }
  qs = st["quarters"]
  qlabels = qs.map { |r| r["q"].sub("-", " ") }
  d = st["this_quarter"]["n"] - st["this_quarter"]["prev_n"]
  real_q = qs.last["real_world"]

  kpis = [
    [st["total"], x(lang, :k_total), nil],
    [st["this_quarter"]["n"], x(lang, :k_quarter) + " · " + st["this_quarter"]["q"], x(lang, :k_vs, p: st["this_quarter"]["prev_n"])],
    ["#{pct(st['direction']['on-ai'], st['total'])}%", x(lang, :k_onai), "#{st['direction']['on-ai']} #{x(lang, :l_cases)}"],
    [fmt_money_short(st["losses"]["total_usd"]), x(lang, :k_losses), x(lang, :l_loss_n, n: st["losses"]["disclosed"])],
    ["#{st['unresolved_pct']}%", x(lang, :k_unresolved), nil],
    [st["autonomous"]["ids"].size, x(lang, :k_auto), nil]
  ].map { |v, l, s| %(<div><b>#{h(v)}</b><span>#{h(l)}</span>#{s ? %(<small>#{h(s)}</small>) : ''}</div>) }.join

  # B. direction per quarter
  s_trend = [[x(lang, :l_onai), "#f5b942", qs.map { |r| r["on-ai"] }], [x(lang, :l_withai), "#5b9cff", qs.map { |r| r["with-ai"] }]]
  trend_svg = legend(s_trend) + stacked_bars(qlabels, s_trend, x(lang, :s_trend_h))
  # C. heat
  cat_rows = st["categories"]
  heat_svg = heat_grid(cat_rows.map { |c| cat_name.call(c["category"]) }, qlabels.map { |l| l.sub(/^20/, "'") }, cat_rows.map { |c| c["by_quarter"] }, x(lang, :s_heat_h))
  # D. autonomous
  auto_by_q = qs.map { |r| r["autonomous"] }
  auto_svg = stacked_bars(qlabels, [[x(lang, :k_auto), "#ff5d62", auto_by_q]], x(lang, :s_auto_h), hgt: 200)
  auto_items = st["autonomous"]["ids"].map { |id| incidents.find { |i| i["id"] == id } }.compact.reverse
  auto_list = %(<ul class="cases auto">#{auto_items.map { |i| li = localized(i, lang) || i; %(<li><time>#{h(fmt_date(i['date'], lang))}</time><span><a href="#{case_url(lang, i['id'])}">#{h(li['title'])}</a></span></li>) }.join}</ul>)
  years = st["years"]
  ay = st["autonomous"]["by_year"]
  # E. actors by year
  s_actors = st["actors"].select { |a| a["n"] > 0 }.each_with_index.map { |a, i| [actor_name.call(a["actor_type"]), CAT_COLORS[i % CAT_COLORS.size], years.map { |y| a["by_year"][y] }] }
  actors_svg = legend(s_actors) + stacked_bars(years, s_actors, x(lang, :s_actors_h), hgt: 240)
  # F. severity per quarter
  s_sev = SEV_ORDER.map { |s| [sev_name.call(s), SEV_COLORS[s], qs.map { |r| r["severity"][s] }] }
  sev_svg = legend(s_sev) + stacked_bars(qlabels, s_sev, x(lang, :s_sev_h), hgt: 240)
  # G. money
  money_rows = st["losses"]["by_category"].select { |c| c["usd"] > 0 }.map { |c| [cat_name.call(c["category"]) + " (#{c['disclosed']})", c["usd"]] }
  money_html = hbars(money_rows, fmt: ->(v) { fmt_money_short(v) })
  # H. sectors
  sector_html = hbars(st["sectors"].map { |s| [s["sector"], s["n"]] })
  # I. geography
  geo_rows = st["countries"].reject { |c| c["country"] == "GL" }.first(10)
  geo_html = %(<table class="pt"><thead><tr><th>#{h(x(lang, :l_country))}</th><th>#{h(x(lang, :l_count))}</th><th>#{h(x(lang, :l_share))}</th></tr></thead><tbody>) +
    %(<tr><td>#{h(x(lang, :l_global))}</td><td class="n">#{st['countries'].find { |c| c['country'] == 'GL' }&.fetch('n', 0)}</td><td class="n">#{st['global_pct']}%</td></tr>) +
    geo_rows.map { |c| %(<tr><td><a href="#{pre(lang)}/cases/country/#{slug(c['country'])}/">#{h(place_name(lang, c['country']))}</a></td><td class="n">#{c['n']}</td><td class="n">#{pct(c['n'], st['total'])}%</td></tr>) }.join + "</tbody></table>"
  top_c = geo_rows.first
  # J. status
  status_html = hbars(st["status"].map { |s| [x(lang, "st_#{s['status'].tr(' ', '_')}".to_sym), s["n"]] })
  speed = st["verify_median_hours"] ? (st["verify_median_hours"] >= 48 ? x(lang, :l_days, d: (st["verify_median_hours"] / 24).round) : x(lang, :l_hours, h: st["verify_median_hours"].round)) : x(lang, :l_na)
  # K. pulse
  pulse = st["pulse"]
  kinds = %w[incident vulnerability research vendor-report policy other untagged]
  s_pulse = kinds.map { |k| [x(lang, "wk_#{k.tr('-', '_')}".to_sym), KIND_COLORS[k], pulse.map { |p| p["kinds"][k] }] }.select { |_, _, v| v.sum > 0 }
  pulse_svg = pulse.empty? ? %(<p class="cap">#{h(x(lang, :l_na))}</p>) : legend(s_pulse) + stacked_bars(pulse.map { |p| p["day"][5, 5] }, s_pulse, x(lang, :s_pulse_h), hgt: 230)

  cap = ->(key, vars = {}) { %(<p class="cap">#{h(x(lang, key, vars))}</p>) }
# For finance and risk teams: what incidents cost, the financial sector, third-party AI products.
fi = st["finance"]
byid = ->(id) { incidents.find { |i| i["id"] == id } }
link = ->(i) { li = localized(i, lang) || i; %(<a href="#{case_url(lang, i['id'])}">#{h(li['title'])}</a>) }
loss_rows = fi["top_losses"].map(&byid).compact.map { |i| %(<tr><td>#{h(fmt_date(i['date'], lang))}</td><td>#{link.call(i)}</td><td class="n">#{h(fmt_money_short(i['loss_usd'].to_f))}</td></tr>) }.join
loss_tbl = %(<table class="pt"><thead><tr><th>#{h(t(lang, 'reported'))}</th><th>#{h(x(lang, :l_case))}</th><th>#{h(x(lang, :l_loss))}</th></tr></thead><tbody>#{loss_rows}</tbody></table>)
fin_svg = stacked_bars(qlabels, [[x(lang, :f_fin_h), "#4fd1a1", fi["fin_by_quarter"]]], x(lang, :f_fin_h), hgt: 180)
fin_list = %(<ul class="cases auto">#{fi['fin_latest'].map(&byid).compact.map { |i| %(<li><time>#{h(fmt_date(i['date'], lang))}</time><span>#{link.call(i)}</span></li>) }.join}</ul>)
tops = fi["fin_by_category"].keys.first(3).map { |c| cat_name.call(c) }.join(", ")
v_rows = fi["vendors"].map { |v| li = v["latest"] && byid.call(v["latest"]); %(<tr><td>#{h(v['product'])}</td><td class="n">#{v['n']}</td><td class="n">#{v['critical_high']}</td><td class="n">#{v['with_cve']}</td><td>#{li ? link.call(li) : ''}</td></tr>) }.join
v_tbl = %(<table class="pt"><thead><tr><th>#{h(x(lang, :l_product))}</th><th>#{h(x(lang, :l_count))}</th><th>#{h(x(lang, :l_ch))}</th><th>#{h(x(lang, :l_cve))}</th><th>#{h(x(lang, :l_latest))}</th></tr></thead><tbody>#{v_rows}</tbody></table>)
finance_html = %(<h2 id="finance" class="fin-h">#{h(x(lang, :fin_h))}</h2><p class="lede">#{h(x(lang, :fin_lede))}</p>) +
  %(<div class="two"><section class="sec"><h2>#{h(x(lang, :f_cost_h))}</h2>#{loss_tbl}#{cap.call(:f_cost_c, n: st['losses']['disclosed'], m: st['total'])}</section>) +
  %(<section class="sec"><h2>#{h(x(lang, :f_fin_h))}</h2>#{fin_svg}#{cap.call(:f_fin_c, n: fi['financial_services'], ind: fi['individuals'], tops: tops)}#{fin_list}</section></div>) +
  %(<section class="sec"><h2>#{h(x(lang, :f_vendor_h))}</h2><div style="overflow-x:auto">#{v_tbl}</div>#{cap.call(:f_vendor_c)}</section>)
  real_note = %(<p class="cap">#{h(x(lang, :l_real_only, n: st['total'] - st['researcher_demos']))}</p>)
  body = <<~HTML
    #{crumbs_html(lang, [[x(lang, :patterns), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(lede)}</p>
    #{share_row(lang, url, title)}
    <div class="kpis">#{kpis}</div>
    <section class="sec"><h2>#{h(x(lang, :s_trend_h))}</h2>#{trend_svg}#{cap.call(:s_trend_c, first: st['on_ai_share_first_half'], last: st['on_ai_share_last_half'])}#{real_note}</section>
    <section class="sec"><h2>#{h(x(lang, :s_heat_h))}</h2>#{heat_svg}#{cap.call(:s_heat_c, rising: cat_name.call(st['rising_category'].to_s), top: cat_name.call(st['top_category'].to_s), topn: st['top_category_n'])}</section>
    <section class="sec"><h2>#{h(x(lang, :s_auto_h))}</h2>#{auto_svg}#{cap.call(:s_auto_c, prev: ay[years[-2]] || 0, prev_year: years[-2], cur: ay[years[-1]] || 0, cur_year: years[-1])}#{auto_list}</section>
    <div class="two">
      <section class="sec"><h2>#{h(x(lang, :s_actors_h))}</h2>#{actors_svg}#{cap.call(:s_actors_c, crim: pct(st['actors'].find { |a| a['actor_type'] == 'criminal' }['n'], st['total']), res: st['researcher_demos'], state: st['actors'].find { |a| a['actor_type'] == 'state' }['n'], unk: st['actors'].find { |a| a['actor_type'] == 'unknown' }['n'])}</section>
      <section class="sec"><h2>#{h(x(lang, :s_sev_h))}</h2>#{sev_svg}#{cap.call(:s_sev_c, chpct: st['critical_high_pct'])}</section>
    </div>
    <div class="two">
      <section class="sec"><h2>#{h(x(lang, :s_money_h))}</h2>#{money_html}#{cap.call(:s_money_c, total: fmt_money_short(st['losses']['total_usd']), n: st['losses']['disclosed'], m: st['total'], deep: st['losses']['deepfake_share_pct'])}</section>
      <section class="sec"><h2>#{h(x(lang, :s_sector_h))}</h2>#{sector_html}#{cap.call(:s_sector_c)}</section>
    </div>
    #{finance_html}
    <div class="two">
      <section class="sec"><h2>#{h(x(lang, :s_geo_h))}</h2>#{geo_html}#{cap.call(:s_geo_c, gl: st['global_pct'], top: top_c ? place_name(lang, top_c['country']) : '—', topn: top_c ? top_c['n'] : 0)}</section>
      <section class="sec"><h2>#{h(x(lang, :s_status_h))}</h2>#{status_html}#{cap.call(:s_status_c, unres: st['unresolved_pct'], speed: speed)}</section>
    </div>
    <section class="sec"><h2>#{h(x(lang, :s_pulse_h))}</h2>#{pulse_svg}#{cap.call(:s_pulse_c)}</section>
    <p class="method">#{h(x(lang, :p_method, n: st['total'], date: fmt_date(st['generated_at'][0, 10], lang), stats: ''))}<a href="/data/stats.json">#{h(x(lang, :l_json))}</a>. #{h(x(lang, :l_embed))}</p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "patterns", headhtml, body, alternates)
end
