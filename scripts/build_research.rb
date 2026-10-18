# Research vs reality: published AI risk warnings (config/research_claims.json) checked against
# the verified case files. Writes the hub at site/research/, one page per warning at
# site/research/<claim-id>/ (per language), and site/data/research.json. Translations of the
# warnings and of the page's own strings live in config/research_i18n/<lang>.json.
# Loaded by build_pages.rb after build_patterns.rb; expects its helpers (head, shell, h, pre,
# fmt_date, case_url, localized, crumbs_*, share_row, lang_links, stacked_bars, quarter_of,
# quarters_between, pct, BASE, LANGS, ROOT, SITE, TREND_FROM).

RESEARCH = JSON.parse(File.read(File.join(ROOT, "config", "research_claims.json"), encoding: "UTF-8"))
RESEARCH_I18N = Hash[LANGS.map { |l| p = File.join(ROOT, "config", "research_i18n", "#{l}.json"); [l, File.exist?(p) ? JSON.parse(File.read(p, encoding: "UTF-8")) : {}] }]
STATUS_ORDER = %w[observed early lab none outside].freeze
STATUS_COLORS = { "observed" => "var(--crit)", "early" => "var(--high)", "lab" => "var(--med)", "none" => "var(--line2)", "outside" => "var(--line)" }.freeze

RESEARCH_CSS = <<~CSS
  .rgroup{margin:26px 0 8px}.rgroup h2{margin:0 0 2px}.rgroup>p{color:var(--muted);margin:0 0 10px}
  .claims{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
  .claim{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:8px;text-decoration:none;color:var(--ink)}
  a.claim:hover{border-color:var(--accent)}.claim h3{margin:0;font-size:16px;line-height:1.3}.claim small{color:var(--muted);font-size:12px}
  .claim .n{font:600 13px var(--f-mono)}.claim .ft{margin-top:auto;display:flex;justify-content:space-between;gap:8px;align-items:center;flex-wrap:wrap}
  .rst{display:inline-flex;align-items:center;gap:6px;font:600 11px var(--f-mono);text-transform:uppercase;letter-spacing:.05em;color:var(--ink)}
  .rst i{width:10px;height:10px;border-radius:50%;display:inline-block;flex:none}
  html[lang="ar"] .rst,html[lang="zh"] .rst{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  .rkey{display:grid;gap:6px;margin:0 0 6px;font-size:13px;color:var(--muted)}.rkey div{display:flex;gap:10px;align-items:baseline;flex-wrap:wrap}
  blockquote.warn{margin:0 0 6px;padding:12px 16px;border-inline-start:3px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;font-size:17px}
  html[dir="rtl"] blockquote.warn{border-radius:10px 0 0 10px}
CSS

def rx(lang, key, vars = {})
  s = (RESEARCH_I18N[lang]["ui"] || {})[key.to_s] || RESEARCH_I18N["en"]["ui"][key.to_s] || key.to_s
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

def claim_text(lang, c, field)
  ((RESEARCH_I18N[lang]["claims"] || {})[c["id"]] || {})[field] || c[field]
end

def group_text(lang, src, gid, field)
  ((RESEARCH_I18N[lang]["groups"] || {})[gid] || {})[field] || src["groups"].find { |g| g["id"] == gid }[field]
end

def research_url(lang, claim_id = nil)
  "#{BASE}#{pre(lang)}/research/#{claim_id ? "#{claim_id}/" : ''}"
end

# claim id => matching verified cases (newest first), from each claim's match rule.
def research_links(incidents)
  Hash[RESEARCH["claims"].map do |c|
    m = c["match"] || {}
    hits = incidents.select do |i|
      next false if (m["exclude"] || []).include?(i["id"])
      (m["ids"] || []).include?(i["id"]) || (m["categories"] || []).include?(i["category"]) || (m["actor_types"] || []).include?(i["actor_type"])
    end
    [c["id"], hits.sort_by { |i| i["date"].to_s }.reverse]
  end]
end

def lab_case?(i)
  i["actor_type"] == "researcher"
end

def months_between(a, b)
  ya, ma = a[0, 4].to_i, a[5, 2].to_i
  yb, mb = b[0, 4].to_i, b[5, 2].to_i
  (yb - ya) * 12 + (mb - ma)
end

def research_stats(incidents, links)
  src = RESEARCH["sources"].first
  claims = RESEARCH["claims"].map do |c|
    hits = links[c["id"]]
    real = hits.reject { |i| lab_case?(i) }
    first = real.map { |i| i["date"] }.min
    { "id" => c["id"], "source" => c["source"], "group" => c["group"], "section" => c["section"], "page" => c["page"], "title" => c["title"], "claim" => c["claim"],
      "status" => c["status"], "note" => c["note"], "n" => hits.size, "real_world" => real.size, "first_real_world" => first,
      "months_after_publication" => first && months_between(src["published"], first), "url" => research_url("en", c["id"]), "cases" => hits.map { |i| i["id"] } }
  end
  matched = links.values.flatten.map { |i| i["id"] }.uniq
  cats = incidents.map { |i| i["category"] }.uniq
  gaps = cats.map { |cat| all = incidents.select { |i| i["category"] == cat }; [cat, all.count { |i| !matched.include?(i["id"]) }, all.size] }.sort_by { |_, u, n| [-u, -n] }
  { "generated_at" => Time.now.utc.iso8601, "licence" => "CC BY 4.0", "sources" => RESEARCH["sources"], "claims" => claims,
    "status_counts" => Hash[STATUS_ORDER.map { |s| [s, claims.count { |c| c["status"] == s }] }],
    "matched_cases" => matched.size, "total_cases" => incidents.size, "unmatched_pct" => pct(incidents.size - matched.size, incidents.size),
    "unmatched_by_category" => gaps.map { |cat, u, n| { "category" => cat, "unmatched" => u, "total" => n } } }
end

def status_pill(lang, s)
  %(<span class="rst"><i style="background:#{STATUS_COLORS[s]}"></i>#{h(rx(lang, "st_#{s}"))}</span>)
end

def first_line(lang, c, src)
  return nil unless c["first_real_world"]
  # Coverage starts in 2025, so a gap after publication says more about the registry than the risk;
  # only a case that predates the paper is worth calling out.
  s = rx(lang, :l_first, date: fmt_date(c["first_real_world"], lang))
  c["months_after_publication"] <= 0 ? "#{s} · #{rx(lang, :l_before)}" : s
end

def matches_label(lang, n)
  n == 1 ? rx(lang, :l_match_one) : rx(lang, :l_matches, n: n)
end

def research_head(lang, title, desc, url, alternates, extra_ld)
  jsonld = extra_ld
  html = head(lang: lang, title: "#{title} · AI Threat Watch", desc: desc, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  html.sub("</style>", PATTERNS_CSS + RESEARCH_CSS + "</style>")
end

def research_page(lang, st, incidents)
  src = st["sources"].first
  url = research_url(lang)
  alternates = Hash[LANGS.map { |l| [l, research_url(l)] }]
  title = rx(lang, :research_h)
  lede = rx(lang, :research_lede)
  ld = [
    { "@context" => "https://schema.org", "@type" => "Dataset", "@id" => url, "name" => title, "description" => lede, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "creator" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "isBasedOn" => { "@type" => "ScholarlyArticle", "name" => src["title"], "url" => src["url"], "author" => src["authors"], "publisher" => { "@type" => "Organization", "name" => src["institute"], "url" => src["institute_url"] } },
      "distribution" => [{ "@type" => "DataDownload", "encodingFormat" => "application/json", "contentUrl" => "#{BASE}/data/research.json" }], "dateModified" => st["generated_at"][0, 10] },
    crumbs_ld(lang, [[rx(lang, :research), url]])
  ]
  sc = st["status_counts"]
  kpis = [
    [st["claims"].size, rx(lang, :k_claims), nil],
    [sc["observed"], rx(lang, :k_observed), nil],
    [sc["early"] + sc["lab"], rx(lang, :k_early), nil],
    [sc["none"], rx(lang, :k_none), nil],
    [sc["outside"], rx(lang, :k_outside), nil],
    [st["matched_cases"], rx(lang, :k_linked), rx(lang, :k_of, n: st["total_cases"])]
  ].map { |v, l, s| %(<div><b>#{h(v)}</b><span>#{h(l)}</span>#{s ? %(<small>#{h(s)}</small>) : ''}</div>) }.join
  key = %(<div class="rkey">#{STATUS_ORDER.select { |s| sc[s] > 0 }.map { |s| %(<div>#{status_pill(lang, s)}<span>#{h(rx(lang, "sd_#{s}"))}</span></div>) }.join}</div>)
  groups = src["groups"].map do |g|
    cards = st["claims"].select { |c| c["group"] == g["id"] }.sort_by { |c| [STATUS_ORDER.index(c["status"]), -c["n"]] }.map do |c|
      fl = first_line(lang, c, src)
      %(<a class="claim" href="#{h(research_url(lang, c['id']))}">#{status_pill(lang, c['status'])}<h3>#{h(claim_text(lang, c, 'title'))}</h3>) +
        %(#{fl ? %(<small>#{h(fl)}</small>) : ''}<div class="ft"><span class="n">#{h(c['n'].zero? ? rx(lang, :l_none_yet) : matches_label(lang, c['n']))}</span><small>§#{h(c['section'])}</small></div></a>)
    end.join
    %(<section class="rgroup"><h2>#{h(group_text(lang, src, g['id'], 'name'))}</h2><p>#{h(group_text(lang, src, g['id'], 'blurb'))}</p><div class="claims">#{cards}</div></section>)
  end.join
  gap_rows = st["unmatched_by_category"].map { |r| %(<tr><td><a href="#{pre(lang)}/cases/category/#{slug(r['category'])}/">#{h(tt(lang, 'cats', r['category']))}</a></td><td class="n">#{r['unmatched']}</td><td class="n">#{r['total']}</td></tr>) }.join
  gap = %(<section class="sec"><h2>#{h(rx(lang, :gap_h))}</h2><p class="cap">#{h(rx(lang, :gap_c, pct: st['unmatched_pct'], n: st['total_cases'] - st['matched_cases'], m: st['total_cases']))}</p>) +
    %(<table class="pt"><thead><tr><th>#{h(rx(lang, :gap_cat))}</th><th>#{h(rx(lang, :gap_unmatched))}</th><th>#{h(rx(lang, :gap_total))}</th></tr></thead><tbody>#{gap_rows}</tbody></table></section>)
  source = %(<section class="sec"><h2>#{h(rx(lang, :src_h))}</h2><p><b>#{h(src['title'])}</b>. #{h(src['authors'])}. #{h(src['institute'])}, #{h(src['version'])}.</p><p>#{h(rx(lang, :src_p, inst: src['institute']))}</p>) +
    %(<p><a class="btn" href="#{h(src['url'])}" rel="noopener" target="_blank">#{h(rx(lang, :l_paper))}</a> <a class="btn ghost" href="#{h(src['summary_url'])}" rel="noopener" target="_blank">#{h(rx(lang, :l_summary))}</a></p></section>)
  body = <<~HTML
    #{crumbs_html(lang, [[rx(lang, :research), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(lede)}</p>
    #{share_row(lang, url, title)}
    <div class="kpis">#{kpis}</div>
    #{key}
    #{groups}
    #{gap}
    #{source}
    <p class="method">#{h(rx(lang, :method))} #{h(rx(lang, :l_coverage))} <a href="/data/research.json">#{h(rx(lang, :l_json))}</a></p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "research", research_head(lang, title, lede, url, alternates, ld), body, alternates)
end

def claim_page(lang, c, st, incidents)
  src = st["sources"].find { |s| s["id"] == c["source"] }
  url = research_url(lang, c["id"])
  alternates = Hash[LANGS.map { |l| [l, research_url(l, c["id"])] }]
  title = claim_text(lang, c, "title")
  warning = claim_text(lang, c, "claim")
  note = claim_text(lang, c, "note")
  byid = Hash[incidents.map { |i| [i["id"], i] }]
  hits = c["cases"].map { |id| byid[id] }.compact
  ld = [
    { "@context" => "https://schema.org", "@type" => "Article", "@id" => url, "mainEntityOfPage" => url, "headline" => title, "description" => "#{warning} #{note}", "inLanguage" => lang,
      "isAccessibleForFree" => true, "license" => "https://creativecommons.org/licenses/by/4.0/", "dateModified" => st["generated_at"][0, 10],
      "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "citation" => { "@type" => "ScholarlyArticle", "name" => src["title"], "url" => src["url"], "author" => src["authors"] } },
    crumbs_ld(lang, [[rx(lang, :research), research_url(lang)], [title, url]])
  ]
  fl = first_line(lang, c, src)
  dated = hits.select { |i| i["date"].to_s >= TREND_FROM }
  timeline = ""
  if dated.size >= 3
    qs = quarters_between(quarter_of(TREND_FROM), quarter_of(Time.now.utc.strftime("%Y-%m-%d")))
    real = qs.map { |q| dated.count { |i| quarter_of(i["date"]) == q && !lab_case?(i) } }
    lab = qs.map { |q| dated.count { |i| quarter_of(i["date"]) == q && lab_case?(i) } }
    series = [[rx(lang, :st_observed), "#ff5d62", real]]
    series << [rx(lang, :l_lab), "#5b9cff", lab] if lab.sum > 0
    timeline = %(<section class="sec"><h2>#{h(rx(lang, :l_timeline))}</h2>#{series.size > 1 ? legend(series) : ''}#{stacked_bars(qs.map { |q| q.sub('-', ' ').sub(/^20/, "'") }, series, rx(lang, :l_timeline), hgt: 200)}</section>)
  end
  list = hits.empty? ? %(<p>#{h(rx(lang, :l_none_yet))}</p>) : %(<ul class="cases auto">#{hits.map { |i| li = localized(i, lang) || i; %(<li><time>#{h(fmt_date(i['date'], lang))}</time><span><a href="#{case_url(lang, i['id'])}">#{h(li['title'])}</a>#{lab_case?(i) ? %( <small>· #{h(rx(lang, :l_lab))}</small>) : ''}</span></li>) }.join}</ul>)
  others = st["claims"].select { |o| o["group"] == c["group"] && o["id"] != c["id"] }.map { |o| %(<li>#{status_pill(lang, o['status'])} <a href="#{h(research_url(lang, o['id']))}">#{h(claim_text(lang, o, 'title'))}</a></li>) }.join
  body = <<~HTML
    #{crumbs_html(lang, [[rx(lang, :research), research_url(lang)], [title, nil]])}
    <article>
    <p class="eyebrow"><span>#{h(group_text(lang, src, c['group'], 'name'))}</span><span>#{h(src['institute'])}</span><span>§#{h(c['section'])}</span></p>
    <h1>#{h(title)}</h1>
    <p class="pills">#{status_pill(lang, c['status'])}<span class="pill">#{h(c['n'].zero? ? rx(lang, :l_none_yet) : matches_label(lang, c['n']))}</span></p>
    #{share_row(lang, url, title)}
    <section class="sec"><h2>#{h(rx(lang, :l_warning))}</h2><blockquote class="warn">#{h(warning)}</blockquote>
    <p class="cap">#{h(rx(lang, :l_paraphrase))} #{h(rx(lang, :l_source))}: <a href="#{h(src['url'])}" rel="noopener" target="_blank">#{h(src['title'])}</a>, #{h(src['institute'])}, #{h(rx(lang, :l_section, s: c['section'], p: c['page']))}.</p></section>
    <section class="sec"><h2>#{h(rx(lang, :l_shows))}</h2><p>#{h(note)}</p><p class="cap">#{h(rx(lang, "sd_#{c['status']}"))}#{fl ? " #{h(fl)}." : ''}</p></section>
    #{timeline}
    <section class="sec"><h2>#{h(rx(lang, :l_all))}</h2>#{list}</section>
    <section class="sec"><h2>#{h(rx(lang, :l_other))}</h2><ul class="srcs">#{others}</ul><p><a href="#{h(research_url(lang))}">#{h(rx(lang, :research))} →</a></p></section>
    </article>
    <p class="method">#{h(rx(lang, :method))} #{h(rx(lang, :l_coverage))} <a href="/data/research.json">#{h(rx(lang, :l_json))}</a></p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "research", research_head(lang, title, warning, url, alternates, ld), body, alternates)
end

# Block for a case page: the warnings this case matches. Empty string when none.
def case_research_html(lang, case_id)
  return "" unless defined?($research_by_case) && $research_by_case
  claims = $research_by_case[case_id] || []
  return "" if claims.empty?
  items = claims.map { |c| %(<li>#{status_pill(lang, c['status'])} <a href="#{h(research_url(lang, c['id']))}">#{h(claim_text(lang, c, 'title'))}</a></li>) }.join
  %(<section class="sec"><h2>#{h(rx(lang, :case_h))}</h2><ul class="srcs">#{items}</ul><p class="cap">#{h(rx(lang, :case_c))}</p></section>)
end
