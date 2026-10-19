# Research vs reality: published AI risk warnings (config/research_claims.json) checked against
# the verified case files. Writes the hub at site/research/, one page per warning at
# site/research/<claim-id>/ (per language), and site/data/research.json. Translations of the
# warnings, groups, source blurbs and the page's own strings live in config/research_i18n/<lang>.json.
# Several sources: the hub has one section per source; a source of kind "taxonomy" (a map of all
# AI risk, not a set of warnings) is left out of "what the research did not foresee".
# Loaded by build_pages.rb after build_patterns.rb; expects its helpers (head, shell, h, pre,
# fmt_date, case_url, localized, crumbs_*, share_row, lang_links, stacked_bars, quarter_of,
# quarters_between, pct, BASE, LANGS, ROOT, SITE, TREND_FROM).

RESEARCH = JSON.parse(File.read(File.join(ROOT, "config", "research_claims.json"), encoding: "UTF-8"))
RESEARCH_I18N = Hash[LANGS.map { |l| p = File.join(ROOT, "config", "research_i18n", "#{l}.json"); [l, File.exist?(p) ? JSON.parse(File.read(p, encoding: "UTF-8")) : {}] }]
# Risk themes put every institute's warnings on the same risk side by side (config/research_themes.json).
RESEARCH_THEMES = JSON.parse(File.read(File.join(ROOT, "config", "research_themes.json"), encoding: "UTF-8"))["themes"]
RESEARCH_THEMES_I18N = JSON.parse(File.read(File.join(ROOT, "config", "research_i18n", "themes.json"), encoding: "UTF-8"))
(RESEARCH["claims"].map { |c| c["id"] } - RESEARCH_THEMES.flat_map { |t| t["claims"] }).each { |id| abort "build_research: claim #{id} is in no theme (config/research_themes.json)" }
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
  .rsrc{margin:34px 0 8px;padding-top:18px;border-top:1px solid var(--line);scroll-margin-top:72px}.rsrc>h2{margin:4px 0 6px}.rsrc>.cap{max-width:70ch}
  .insts{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px;margin:8px 0 6px}
  .inst{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:8px}
  .inst h3{margin:0;font-size:18px}.inst small{color:var(--muted);font-size:12px;line-height:1.4}.inst .n{font:600 13px var(--f-mono)}.inst a.more{margin-top:auto;font-size:14px}
  .sbar{display:flex;height:8px;border-radius:4px;overflow:hidden;background:var(--line)}.sbar i{display:block;height:100%}
  .scount{display:flex;flex-wrap:wrap;gap:4px 12px;font-size:12px;color:var(--muted)}.scount span{display:inline-flex;align-items:center;gap:5px}.scount i{width:8px;height:8px;border-radius:50%;display:inline-block}
  .claim .who{font:600 11px var(--f-mono);text-transform:uppercase;letter-spacing:.05em;color:var(--accent)}
  html[lang="ar"] .claim .who,html[lang="zh"] .claim .who{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  .rtheme{margin:26px 0 8px;scroll-margin-top:72px}.rtheme h3{margin:0 0 2px;font-size:20px}.rtheme>p{color:var(--muted);margin:0 0 4px}.rtheme>p.tl{font:600 13px var(--f-mono);color:var(--ink);margin:0 0 10px}
  details.rinst{border:1px solid var(--line);border-radius:12px;background:var(--surface);margin:10px 0;scroll-margin-top:72px}
  details.rinst>summary{cursor:pointer;padding:14px 16px;font:600 17px var(--f-body);list-style-position:inside}details.rinst>summary small{font:13px var(--f-body);color:var(--muted);margin-inline-start:8px}
  details.rinst>.in{padding:0 16px 16px}details.rinst .rsrc{margin:10px 0 8px;border-top:1px solid var(--line)}
  a.btn small{font-weight:400;opacity:.8;margin-inline-start:8px;padding-inline-start:8px;border-inline-start:1px solid currentColor}
  .rgroup h3{margin:0 0 2px;font-size:18px}.rsrcs{list-style:none;padding:0;margin:0;display:grid;gap:16px}.rsrcs p{margin:0 0 6px}
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

def source_text(lang, src, field)
  ((RESEARCH_I18N[lang]["sources"] || {})[src["id"]] || {})[field] || src[field]
end

def research_url(lang, claim_id = nil)
  "#{BASE}#{pre(lang)}/research/#{claim_id ? "#{claim_id}/" : ''}"
end

def taxonomy?(src)
  src["kind"] == "taxonomy"
end

# Where in the source a claim comes from: a numbered section with an optional page, a taxonomy
# domain, or a named section of a web report without pages.
def section_label(lang, c, src)
  s, p = c["section"].to_s, c["page"]
  return rx(lang, :l_domain, s: s, p: p) if taxonomy?(src)
  return rx(lang, :l_section_named, s: s) unless s =~ /\A[\d.]/
  p ? rx(lang, :l_section, s: s, p: p) : rx(lang, :l_section_only, s: s)
end

def section_short(lang, c, src)
  s = c["section"].to_s
  return rx(lang, :l_domain_short, s: s) if taxonomy?(src)
  s =~ /\A[\d.]/ ? "§#{s}" : ""
end

# claim id => matching verified cases (newest first), from each claim's match rule.
def research_links(incidents)
  Hash[RESEARCH["claims"].map do |c|
    m = c["match"] || {}
    hits = incidents.select do |i|
      next false if (m["exclude"] || []).include?(i["id"])
      next false if (m["exclude_actor_types"] || []).include?(i["actor_type"]) && !(m["ids"] || []).include?(i["id"])
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
  sources = Hash[RESEARCH["sources"].map { |s| [s["id"], s] }]
  claims = RESEARCH["claims"].map do |c|
    src = sources.fetch(c["source"])
    hits = links[c["id"]]
    real = hits.reject { |i| lab_case?(i) }
    first = real.map { |i| i["date"] }.min
    { "id" => c["id"], "source" => c["source"], "group" => c["group"], "section" => c["section"], "page" => c["page"], "title" => c["title"], "claim" => c["claim"],
      "status" => c["status"], "note" => c["note"], "n" => hits.size, "real_world" => real.size, "first_real_world" => first,
      "months_after_publication" => first && !taxonomy?(src) ? months_between(src["published"], first) : nil, "url" => research_url("en", c["id"]), "cases" => hits.map { |i| i["id"] } }
  end
  per_source = RESEARCH["sources"].map do |s|
    cl = claims.select { |c| c["source"] == s["id"] }
    ids = cl.flat_map { |c| c["cases"] }.uniq
    { "source" => s["id"], "claims" => cl.size, "matched_cases" => ids.size, "matched_pct" => pct(ids.size, incidents.size),
      "status_counts" => Hash[STATUS_ORDER.map { |st| [st, cl.count { |c| c["status"] == st }] }] }
  end
  # "Not foreseen" is measured against the warnings only: a taxonomy is built to cover everything.
  warn_ids = claims.reject { |c| taxonomy?(sources[c["source"]]) }.flat_map { |c| c["cases"] }.uniq
  matched = claims.flat_map { |c| c["cases"] }.uniq
  cats = incidents.map { |i| i["category"] }.uniq
  gaps = cats.map { |cat| all = incidents.select { |i| i["category"] == cat }; [cat, all.count { |i| !warn_ids.include?(i["id"]) }, all.size] }.sort_by { |_, u, n| [-u, -n] }
  { "generated_at" => Time.now.utc.iso8601, "licence" => "CC BY 4.0", "sources" => RESEARCH["sources"], "claims" => claims, "by_source" => per_source,
    "status_counts" => Hash[STATUS_ORDER.map { |s| [s, claims.count { |c| c["status"] == s }] }],
    "matched_cases" => matched.size, "total_cases" => incidents.size, "warning_matched_cases" => warn_ids.size,
    "unmatched_pct" => pct(incidents.size - warn_ids.size, incidents.size),
    "unmatched_by_category" => gaps.map { |cat, u, n| { "category" => cat, "unmatched" => u, "total" => n } } }
end

def status_pill(lang, s)
  %(<span class="rst"><i style="background:#{STATUS_COLORS[s]}"></i>#{h(rx(lang, "st_#{s}"))}</span>)
end

def first_line(lang, c, src)
  return nil unless c["first_real_world"] && c["months_after_publication"]
  # Coverage starts in 2025, so a gap after publication says more about the registry than the risk;
  # only a case that predates the source is worth calling out.
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

def source_ld(src)
  { "@type" => taxonomy?(src) ? "Dataset" : (src["kind"] == "paper" ? "ScholarlyArticle" : "Report"), "name" => src["title"], "url" => src["url"], "author" => src["authors"],
    "datePublished" => src["published"], "publisher" => { "@type" => "Organization", "name" => src["institute"], "url" => src["institute_url"] } }
end

def source_cite(lang, src)
  %(<b>#{h(src['title'])}</b>. #{h(src['authors'])}. #{h(src['institute'])}, #{h(src['version'])}.)
end

# A link's destination as readers see it in the address bar: safe.ai/ai-risk, arxiv.org/abs/2306.12001.
def url_label(u)
  host, path = u.to_s.sub(%r{\Ahttps?://(www\.)?}, "").sub(%r{/\z}, "").split("/", 2)
  path && path.size <= 12 ? "#{host}/#{path}" : host
end

# Each button names the site it opens, so two buttons going to two sites is not a surprise.
def source_links(lang, src)
  %(<a class="btn" href="#{h(src['url'])}" rel="noopener" target="_blank">#{h(rx(lang, :l_paper))} <small dir="ltr">#{h(url_label(src['url']))}</small></a>) +
    (src["summary_url"] ? %( <a class="btn ghost" href="#{h(src['summary_url'])}" rel="noopener" target="_blank">#{h(rx(lang, :l_summary, inst: src['institute']))} <small dir="ltr">#{h(url_label(src['summary_url']))}</small></a>) : "")
end

def thx(lang, key, vars = {})
  s = ((RESEARCH_THEMES_I18N[lang] || {})["ui"] || {})[key.to_s] || RESEARCH_THEMES_I18N["en"]["ui"][key.to_s]
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

def theme_text(lang, tid, field)
  (((RESEARCH_THEMES_I18N[lang] || {})["themes"] || {})[tid] || {})[field] || RESEARCH_THEMES_I18N["en"]["themes"][tid][field]
end

# Institutes in alphabetical order, each with its sources (METR has two), so no institute leads.
def research_institutes(st)
  st["sources"].group_by { |s| s["institute"] }.map { |name, srcs| { "name" => name, "slug" => slug(name), "sources" => srcs, "short" => srcs.first["short"] } }.sort_by { |i| i["name"].downcase }
end

def status_counts_html(lang, counts)
  total = [counts.values.sum, 1].max
  bar = STATUS_ORDER.select { |s| counts[s].to_i > 0 }.map { |s| %(<i style="width:#{(100.0 * counts[s] / total).round(2)}%;background:#{STATUS_COLORS[s]}" title="#{h(rx(lang, "st_#{s}"))}: #{counts[s]}"></i>) }.join
  list = STATUS_ORDER.select { |s| counts[s].to_i > 0 }.map { |s| %(<span><i style="background:#{STATUS_COLORS[s]}"></i>#{h(rx(lang, "st_#{s}"))} #{counts[s]}</span>) }.join
  %(<div class="sbar">#{bar}</div><div class="scount">#{list}</div>)
end

def claim_card(lang, c, src, who: false)
  fl = first_line(lang, c, src)
  ss = section_short(lang, c, src)
  %(<a class="claim" href="#{h(research_url(lang, c['id']))}">#{who ? %(<span class="who">#{h(src['institute'])}</span>) : ''}#{status_pill(lang, c['status'])}<h3>#{h(claim_text(lang, c, 'title'))}</h3>) +
    %(#{fl ? %(<small>#{h(fl)}</small>) : ''}<div class="ft"><span class="n">#{h(c['n'].zero? ? rx(lang, :l_none_yet) : matches_label(lang, c['n']))}</span>#{ss.empty? ? '' : %(<small><bdi>#{h(ss)}</bdi></small>)}</div></a>)
end

def research_page(lang, st, incidents)
  url = research_url(lang)
  alternates = Hash[LANGS.map { |l| [l, research_url(l)] }]
  title = rx(lang, :research_h)
  lede = rx(lang, :research_lede)
  ld = [
    { "@context" => "https://schema.org", "@type" => "Dataset", "@id" => url, "name" => title, "description" => lede, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "creator" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "isBasedOn" => st["sources"].map { |s| source_ld(s) },
      "distribution" => [{ "@type" => "DataDownload", "encodingFormat" => "application/json", "contentUrl" => "#{BASE}/data/research.json" }], "dateModified" => st["generated_at"][0, 10] },
    crumbs_ld(lang, [[rx(lang, :research), url]])
  ]
  sc = st["status_counts"]
  kpis = [
    [st["sources"].map { |s| s["institute"] }.uniq.size, rx(lang, :k_sources), nil, :r_sources],
    [st["claims"].size, rx(lang, :k_claims), nil, :r_claims],
    [sc["observed"], rx(lang, :k_observed), nil, :r_observed],
    [sc["early"] + sc["lab"], rx(lang, :k_early), nil, :r_early],
    [sc["none"], rx(lang, :k_none), nil, :r_none],
    [sc["outside"], rx(lang, :k_outside), nil, :r_outside],
    [st["warning_matched_cases"], rx(lang, :k_linked), thx(lang, :k_linked_note, n: st["total_cases"]), :r_linked]
  ].map { |v, l, s, tip| %(<div><b>#{h(v)}</b><span>#{h(l)}#{info_tip(lang, tip)}</span>#{s ? %(<small>#{h(s)}</small>) : ''}</div>) }.join
  key = %(<div class="rkey">#{STATUS_ORDER.select { |s| sc[s] > 0 }.map { |s| %(<div>#{status_pill(lang, s)}<span>#{h(rx(lang, "sd_#{s}"))}</span></div>) }.join}</div>)
  srcs = Hash[st["sources"].map { |s| [s["id"], s] }]
  insts = research_institutes(st)
  # 1. One card per institute, same size and alphabetical, so no institute leads the page.
  inst_cards = insts.map do |inst|
    ids = inst["sources"].map { |s| s["id"] }
    mine = st["claims"].select { |c| ids.include?(c["source"]) }
    counts = Hash[STATUS_ORDER.map { |s| [s, mine.count { |c| c["status"] == s }] }]
    cases = mine.flat_map { |c| c["cases"] }.uniq.size
    papers = inst["sources"].map { |s| %(<a href="#{h(s['url'])}" rel="noopener" target="_blank">#{h(s['title'])}</a> · #{h(fmt_date(s['published'], lang))}) }.join("<br>")
    papers += inst["sources"].map { |s| s["summary_url"] }.compact.uniq.map { |u| %(<br><a href="#{h(u)}" rel="noopener" target="_blank" dir="ltr">#{h(url_label(u))}</a>) }.join
    %(<div class="inst"><h3>#{h(inst['name'])}</h3><small>#{papers}</small><span class="n">#{h(thx(lang, :inst_warnings, n: mine.size))} · #{h(thx(lang, :inst_cases, n: cases))}</span>#{status_counts_html(lang, counts)}<a class="more" href="#inst-#{h(inst['slug'])}">#{h(thx(lang, :inst_see))} →</a></div>)
  end.join
  institutes = %(<section class="sec"><h2>#{h(thx(lang, :inst_h))}</h2><p class="cap">#{h(thx(lang, :inst_c))}</p><div class="insts">#{inst_cards}</div></section>)
  # 2. Risk themes: every institute's warning on the same risk side by side, institutes alphabetical.
  inst_order = Hash[insts.each_with_index.map { |i, k| [i["name"], k] }]
  themes = RESEARCH_THEMES.map do |th|
    # Round robin: each institute shows one warning before any shows a second.
    by_inst = st["claims"].select { |c| th["claims"].include?(c["id"]) }.group_by { |c| srcs[c["source"]]["institute"] }.sort_by { |name, _| inst_order[name] }.map { |_, cs| cs.sort_by { |c| th["claims"].index(c["id"]) } }
    mine = (0...(by_inst.map(&:size).max || 0)).flat_map { |r| by_inst.map { |cs| cs[r] }.compact }
    k = mine.map { |c| srcs[c["source"]]["institute"] }.uniq.size
    n = mine.flat_map { |c| c["cases"] }.uniq.size
    %(<div class="rtheme" id="theme-#{h(th['id'])}"><h3>#{h(theme_text(lang, th['id'], 'name'))}</h3><p>#{h(theme_text(lang, th['id'], 'blurb'))}</p>) +
      %(<p class="tl">#{h(thx(lang, :theme_line, k: k, t: insts.size, n: n))}</p><div class="claims">#{mine.map { |c| claim_card(lang, c, srcs[c['source']], who: true) }.join}</div></div>)
  end.join
  themes_html = %(<section class="sec"><h2>#{h(thx(lang, :theme_h))}</h2><p class="cap">#{h(thx(lang, :theme_c))}</p>#{themes}</section>)
  # 3. Each institute's own list, all collapsed the same way.
  per_source = st["sources"].map do |src|
    mine = st["claims"].select { |c| c["source"] == src["id"] }
    groups = src["groups"].map do |g|
      cards = mine.select { |c| c["group"] == g["id"] }.sort_by { |c| taxonomy?(src) ? [c["section"].to_i, 0] : [STATUS_ORDER.index(c["status"]), -c["n"]] }.map { |c| claim_card(lang, c, src) }.join
      %(<div class="rgroup"><h3>#{h(group_text(lang, src, g['id'], 'name'))}</h3><p>#{h(group_text(lang, src, g['id'], 'blurb'))}</p><div class="claims">#{cards}</div></div>)
    end.join
    %(<section class="rsrc" id="src-#{h(src['id'])}"><p class="eyebrow"><span>#{h(src['institute'])}</span><span>#{h(fmt_date(src['published'], lang))}</span>#{taxonomy?(src) ? %(<span>#{h(rx(lang, :l_taxonomy))}</span>) : ''}</p>) +
      %(<h2>#{h(src['title'])}</h2><p class="cap">#{h(source_text(lang, src, 'about'))}</p>#{groups}</section>)
  end
  per_inst = insts.map do |inst|
    n = st["claims"].count { |c| inst["sources"].any? { |x| x["id"] == c["source"] } }
    %(<details class="rinst" id="inst-#{h(inst['slug'])}"><summary>#{h(inst['name'])}<small>#{h(thx(lang, :inst_warnings, n: n))}</small></summary><div class="in">#{inst['sources'].map { |x| per_source[st['sources'].index(x)] }.join}</div></details>)
  end.join
  by_inst_html = %(<section class="sec"><h2>#{h(thx(lang, :by_inst_h))}</h2><p class="cap">#{h(thx(lang, :by_inst_c))}</p>#{per_inst}</section>)
  by_src = Hash[st["by_source"].map { |r| [r["source"], r] }]
  src_rows = insts.flat_map { |i| i["sources"] }.map { |s| r = by_src[s["id"]]; %(<tr><td><a href="#inst-#{h(slug(s["institute"]))}">#{h(s['short'])}</a> <small>#{h(s['title'])}</small></td><td class="n">#{r['claims']}</td><td class="n">#{r['matched_cases']}</td><td class="n">#{r['matched_pct']}%</td></tr>) }.join
  src_table = %(<h3 class="sub">#{h(rx(lang, :cov_h))}</h3><table class="pt"><thead><tr><th>#{h(rx(lang, :l_source))}</th><th>#{h(rx(lang, :k_claims))}</th><th>#{h(rx(lang, :cov_cases))}</th><th>#{h(rx(lang, :cov_share))}</th></tr></thead><tbody>#{src_rows}</tbody></table>)
  gap_rows = st["unmatched_by_category"].map { |r| %(<tr><td><a href="#{pre(lang)}/cases/category/#{slug(r['category'])}/">#{h(tt(lang, 'cats', r['category']))}</a></td><td class="n">#{r['unmatched']}</td><td class="n">#{r['total']}</td></tr>) }.join
  unmatched = st["total_cases"] - st["warning_matched_cases"]
  gap = %(<section class="sec"><h2>#{h(rx(lang, :gap_h))}</h2><p class="cap">#{h(rx(lang, :gap_c, pct: st['unmatched_pct'], n: unmatched, m: st['total_cases']))}</p>) +
    %(<table class="pt"><thead><tr><th>#{h(rx(lang, :gap_cat))}</th><th>#{h(rx(lang, :gap_unmatched))}</th><th>#{h(rx(lang, :gap_total))}</th></tr></thead><tbody>#{gap_rows}</tbody></table>#{src_table}</section>)
  source = %(<section class="sec"><h2>#{h(rx(lang, :src_h))}</h2><p>#{h(rx(lang, :src_p))}</p><ul class="rsrcs">#{st['sources'].map { |s| %(<li><p>#{source_cite(lang, s)}</p><p>#{source_links(lang, s)}</p></li>) }.join}</ul></section>)
  body = <<~HTML
    #{crumbs_html(lang, [[rx(lang, :research), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(lede)}</p>
    #{share_row(lang, url, title)}
    <div class="kpis">#{kpis}</div>
    #{key}
    #{institutes}
    #{themes_html}
    #{by_inst_html}
    <script>function o(){var d=location.hash&&document.getElementById(location.hash.slice(1));if(d&&d.tagName==="DETAILS"){d.open=true;d.scrollIntoView()}}addEventListener("hashchange",o);o()</script>
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
      "citation" => source_ld(src) },
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
  others = st["claims"].select { |o| o["source"] == c["source"] && o["group"] == c["group"] && o["id"] != c["id"] }.map { |o| %(<li>#{status_pill(lang, o['status'])} <a href="#{h(research_url(lang, o['id']))}">#{h(claim_text(lang, o, 'title'))}</a></li>) }.join
  others_sec = others.empty? ? "" : %(<section class="sec"><h2>#{h(rx(lang, :l_other))}</h2><ul class="srcs">#{others}</ul></section>)
  # Warnings from other sources that the same case files support, most shared cases first.
  related = c["cases"].empty? ? [] : st["claims"].select { |o| o["source"] != c["source"] }.map { |o| [o, (o["cases"] & c["cases"]).size] }.select { |_, n| n > 0 }.sort_by { |o, n| [-n, o["id"]] }.first(6)
  related_sec = related.empty? ? "" : %(<section class="sec"><h2>#{h(rx(lang, :l_related))}</h2><ul class="srcs">#{related.map { |o, n| os = st['sources'].find { |s| s['id'] == o['source'] }; %(<li>#{status_pill(lang, o['status'])} <a href="#{h(research_url(lang, o['id']))}">#{h(claim_text(lang, o, 'title'))}</a> <small>· #{h(os['short'])} · #{h(rx(lang, :l_shared, n: n))}</small></li>) }.join}</ul><p class="cap">#{h(rx(lang, :l_related_c))}</p></section>)
  body = <<~HTML
    #{crumbs_html(lang, [[rx(lang, :research), research_url(lang)], [title, nil]])}
    <article>
    <p class="eyebrow"><span>#{h(src['institute'])}</span><span>#{h(group_text(lang, src, c['group'], 'name'))}</span>#{section_short(lang, c, src).empty? ? '' : %(<span><bdi>#{h(section_short(lang, c, src))}</bdi></span>)}</p>
    <h1>#{h(title)}</h1>
    <p class="pills">#{status_pill(lang, c['status'])}<span class="pill">#{h(c['n'].zero? ? rx(lang, :l_none_yet) : matches_label(lang, c['n']))}</span></p>
    #{share_row(lang, url, title)}
    <section class="sec"><h2>#{h(rx(lang, taxonomy?(src) ? :l_domain_h : :l_warning))}</h2><blockquote class="warn">#{h(warning)}</blockquote>
    <p class="cap">#{h(rx(lang, :l_paraphrase))} #{h(rx(lang, :l_source))}: <a href="#{h(src['url'])}" rel="noopener" target="_blank">#{h(src['title'])}</a>, #{src['title'].start_with?(src['institute']) ? '' : "#{h(src['institute'])}, "}#{h(fmt_date(src['published'], lang))}, #{h(section_label(lang, c, src))}.#{src['summary_url'] ? %( #{h(rx(lang, :l_summary, inst: src['institute']))}: <a href="#{h(src['summary_url'])}" rel="noopener" target="_blank" dir="ltr">#{h(url_label(src['summary_url']))}</a>.) : ''}</p></section>
    <section class="sec"><h2>#{h(rx(lang, :l_shows))}</h2><p>#{h(note)}</p><p class="cap">#{h(rx(lang, "sd_#{c['status']}"))}#{fl ? " #{h(fl)}." : ''}</p></section>
    #{timeline}
    #{research_history_html(lang, c)}
    <section class="sec"><h2>#{h(rx(lang, :l_all))}</h2>#{list}</section>
    #{related_sec}
    #{others_sec}
    <p><a href="#{h(research_url(lang))}#src-#{h(src['id'])}">#{h(rx(lang, :research))} · #{h(src['short'])} →</a></p>
    </article>
    <p class="method">#{h(rx(lang, :method))} #{h(rx(lang, :l_coverage))} <a href="/data/research.json">#{h(rx(lang, :l_json))}</a></p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "research", research_head(lang, title, warning, url, alternates, ld), body, alternates)
end

# Block for a case page: the warnings this case matches, with their source. Empty string when none.
def case_research_html(lang, case_id)
  return "" unless defined?($research_by_case) && $research_by_case
  claims = $research_by_case[case_id] || []
  return "" if claims.empty?
  shorts = Hash[RESEARCH["sources"].map { |s| [s["id"], s["short"]] }]
  items = claims.map { |c| %(<li>#{status_pill(lang, c['status'])} <a href="#{h(research_url(lang, c['id']))}">#{h(claim_text(lang, c, 'title'))}</a> <small>· #{h(shorts[c['source']])}</small></li>) }.join
  %(<section class="sec"><h2>#{h(rx(lang, :case_h))}</h2><ul class="srcs">#{items}</ul><p class="cap">#{h(rx(lang, :case_c))}</p></section>)
end
