# Industries at risk: an overview of the ten sectors (site/sectors/) and one page per sector
# (site/sectors/<slug>/), per language. Each sector page combines the verified case files
# (last 12 months, archive count), the official warnings archive (site/data/warnings.json,
# kept by update.rb), the attack types and AI products in the sector's cases, and the latest
# wire stories tagged with the sector. Loaded by build_pages.rb after build_patterns.rb;
# expects its helpers (head, shell, x, t, tt, h, pre, fmt_date, case_url, case_row, localized,
# crumbs_*, share_row, lang_links, fmt_money_short, pct, hbars, sector_name, AI_PRODUCTS,
# WIN_FROM, BASE, LANGS, SITE).

require_relative "sector_strings"

SECTORS_CSS = <<~CSS
  .sgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;margin:8px 0 18px}
  .scard{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:6px;text-decoration:none;color:var(--ink)}
  a.scard:hover{border-color:var(--accent)}.scard h3{margin:0;font-size:17px}.scard p{margin:0;font-size:13px;color:var(--muted);line-height:1.45}
  .scard .nums{display:flex;flex-wrap:wrap;gap:4px 14px;font:600 12px var(--f-mono);margin-top:auto}.scard .up{color:var(--crit)}.scard .down{color:var(--up,#4fd1a1)}
  html[lang="ar"] .scard .nums,html[lang="zh"] .scard .nums{font-family:var(--f-body)}
  ul.warns{list-style:none;margin:0;padding:0;display:grid;gap:10px}
  ul.warns li{background:var(--surface2);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
  ul.warns .wm{display:flex;flex-wrap:wrap;gap:6px 12px;align-items:center;font:12px var(--f-mono);color:var(--muted);margin:0 0 4px}
  html[lang="ar"] ul.warns .wm,html[lang="zh"] ul.warns .wm{font-family:var(--f-body)}
  ul.warns .wk{font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:var(--accent)}
  ul.warns h3{margin:0 0 4px;font-size:15px;line-height:1.35}ul.warns p{margin:0;font-size:13px;color:var(--muted)}
  ul.wwire{list-style:none;margin:0;padding:0;display:grid;gap:8px}ul.wwire li{display:grid;grid-template-columns:96px 1fr;gap:12px;font-size:14px}
  ul.wwire time,ul.wwire small{font:12px var(--f-mono);color:var(--muted)}
  details.more-cases>summary{cursor:pointer;margin:10px 0;font-weight:600}
  @media (max-width:600px){ul.wwire li{grid-template-columns:1fr}}
CSS

def sx(lang, key, vars = {})
  s = (SECTOR_UI[lang] || {})[key] || SECTOR_UI["en"][key] || key.to_s
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

def sector_url(lang, slug = nil)
  "#{BASE}#{pre(lang)}/sectors/#{slug ? "#{slug}/" : ''}"
end

# Numbers for one sector value (also used for the individuals / multiple rows of the overview).
def sector_numbers(incidents, warnings, sector)
  prev_from = (Date.parse(WIN_FROM) - 365).strftime("%Y-%m-%d")
  mine = incidents.select { |i| (i["sector"] || "Unknown") == sector }
  cur = mine.select { |i| i["date"].to_s >= WIN_FROM }
  prev = mine.select { |i| i["date"].to_s >= prev_from && i["date"].to_s < WIN_FROM }
  cats = cur.group_by { |i| i["category"] }.map { |c, v| [c, v.size] }.sort_by { |c, n| [-n, c.to_s] }
  w = warnings.select { |x| Array(x["sectors"]).include?(sector) && x["date"].to_s >= WIN_FROM }
  { "all" => mine, "cur" => cur, "prev" => prev, "cats" => cats, "warnings" => w,
    "ch" => cur.count { |i| %w[critical high].include?(i["severity"]) }, "loss" => cur.sum { |i| i["loss_usd"].to_f } }
end

def change_txt(lang, cur, prev)
  d = cur - prev
  sx(lang, :k_change, d: (d.positive? ? "+#{d}" : d.to_s))
end

def warn_list(lang, items)
  return %(<p class="cap">#{h(sx(lang, :s_warn_none))}</p>) if items.empty?
  lis = items.map do |w|
    meta = [%(<span class="wk">#{h(sx(lang, "wk_#{w['kind']}".to_sym))}</span>), %(<time datetime="#{h(w['date'])}">#{h(fmt_date(w['date'], lang))}</time>),
            %(<span>#{h(w['who'])}#{w['who_type'] ? " · #{h(sx(lang, "wt_#{w['who_type']}".to_sym))}" : ''}</span>), (w["country"] ? %(<span>#{h(w['country'] == 'INT' ? 'INT' : w['country'] == 'EU' ? 'EU' : place_name(lang, w['country']))}</span>) : nil)].compact.join
    %(<li><div class="wm">#{meta}</div><h3><a href="#{h(w['url'])}" rel="noopener" target="_blank" lang="en">#{h(w['title'])}</a></h3><p lang="en">#{h(w['summary'])}</p><p><small>#{h(sx(lang, :l_source))}: #{h(w['source'])}</small></p></li>)
  end.join
  %(<ul class="warns">#{lis}</ul>#{lang == 'en' ? '' : %(<p class="cap"><small>#{h(sx(lang, :s_warn_lang))}</small></p>)})
end

def sector_page(lang, slug, sector, incidents, warnings, wire)
  url = sector_url(lang, slug)
  alternates = Hash[LANGS.map { |l| [l, sector_url(l, slug)] }]
  name = sector_name(lang, sector)
  title = "#{name}: #{sx(lang, :ind_h).split(':').first}"
  desc = sx(lang, "sd_#{slug.tr('-', '_')}".to_sym)
  n = sector_numbers(incidents, warnings, sector)
  jsonld = [{ "@context" => "https://schema.org", "@type" => "CollectionPage", "@id" => url, "name" => title, "description" => desc, "url" => url, "inLanguage" => lang,
              "isPartOf" => { "@type" => "WebSite", "name" => "AI Threat Watch", "url" => "#{BASE}/" } },
            crumbs_ld(lang, [[sx(lang, :industries), sector_url(lang)], [name, url]])]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: desc, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  headhtml = headhtml.sub("</style>", PATTERNS_CSS + SECTORS_CSS + "</style>")
  top = n["cats"].first
  kpis = [
    [n["cur"].size, sx(lang, :k_cases), change_txt(lang, n["cur"].size, n["prev"].size) + " · " + x(lang, :all_time_n, n: n["all"].size)],
    [n["ch"], sx(lang, :k_ch), nil],
    [fmt_money_short(n["loss"]), sx(lang, :k_loss), nil],
    [n["warnings"].size, sx(lang, :k_warn), nil],
    [top ? tt(lang, "cats", top[0]) : sx(lang, :l_none), sx(lang, :k_top), top ? "#{top[1]}" : nil]
  ].map { |v, l, s| %(<div><b>#{h(v)}</b><span>#{h(l)}</span>#{s ? %(<small>#{h(s)}</small>) : ''}</div>) }.join
  cur_sorted = n["cur"].sort_by { |i| i["date"].to_s }.reverse
  first, rest = cur_sorted.first(10), cur_sorted.drop(10)
  older = n["all"].size - n["cur"].size
  cases_html = %(<ul class="cases">#{first.map { |i| case_row(lang, i) }.join}</ul>) +
    (rest.empty? ? "" : %(<details class="more-cases"><summary>+#{rest.size}</summary><ul class="cases">#{rest.map { |i| case_row(lang, i) }.join}</ul></details>)) +
    (older.positive? ? %(<p class="cap">#{h(x(lang, :older_h))}: #{older}</p>) : "")
  products = AI_PRODUCTS.map { |pname, re| [pname, n["cur"].count { |i| [i["title"], i["target"], i["vector"], i["summary"]].join(" ") =~ re }] }.select { |_, c| c.positive? }.sort_by { |p, c| [-c, p] }.first(8)
  how = hbars(n["cats"].first(6).map { |c, k| [tt(lang, "cats", c), k] }) +
    %(<h3 class="sub">#{h(sx(lang, :l_products))}</h3>) + (products.empty? ? %(<p class="cap">#{h(sx(lang, :l_none))}</p>) : hbars(products))
  stories = wire.select { |w| w["sector"] == sector }.first(8)
  watch = stories.empty? ? %(<p class="cap">#{h(sx(lang, :s_watch_none))}</p>) :
    %(<ul class="wwire">#{stories.map { |w| %(<li><time>#{h(fmt_date(w['seen'].to_s[0, 10], lang))}</time><span><a href="#{h(w['url'])}" rel="noopener" target="_blank">#{h(w['one_line'] || w['title'])}</a> <small>#{h(w['source'])}</small></span></li>) }.join}</ul>)
  extra = slug == "education" ? %(<p><a href="#{pre(lang)}/education/">#{h(sx(lang, :l_edu_hub))}</a></p>) : ""
  body = <<~HTML
    #{crumbs_html(lang, [[sx(lang, :industries), "#{pre(lang)}/sectors/"], [name, nil]])}
    <h1>#{h(name)}</h1>
    <p class="lede">#{h(desc)}</p>
    <p class="winlbl">#{h(x(lang, :w12_since, date: fmt_date(WIN_FROM, lang)))}</p>
    #{share_row(lang, url, title)}
    <div class="kpis">#{kpis}</div>
    #{extra}
    <section class="sec" id="warnings"><h2>#{h(sx(lang, :s_warn_h))}</h2><p class="cap">#{h(sx(lang, :s_warn_c))}</p>#{warn_list(lang, n['warnings'].first(20))}</section>
    <section class="sec" id="cases"><h2>#{h(sx(lang, :s_cases_h))}</h2>#{cases_html}</section>
    <div class="two">
      <section class="sec"><h2>#{h(sx(lang, :s_how_h))}</h2><p class="cap">#{h(sx(lang, :s_how_c))}</p>#{how}</section>
      <section class="sec"><h2>#{h(sx(lang, :s_watch_h))}</h2>#{watch}</section>
    </div>
    <p><a href="#{pre(lang)}/sectors/">← #{h(sx(lang, :l_all_sectors))}</a></p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "sectors", headhtml, body, alternates)
end

def sectors_hub(lang, incidents, warnings)
  url = sector_url(lang)
  alternates = Hash[LANGS.map { |l| [l, sector_url(l)] }]
  title = sx(lang, :ind_h)
  lede = sx(lang, :ind_lede)
  rows = SECTORS.map { |slug, sector| [slug, sector, sector_numbers(incidents, warnings, sector)] }.sort_by { |_, _, n| -n["cur"].size }
  jsonld = [{ "@context" => "https://schema.org", "@type" => "CollectionPage", "@id" => url, "name" => title, "description" => lede, "url" => url, "inLanguage" => lang,
              "hasPart" => SECTORS.keys.map { |s| { "@type" => "WebPage", "url" => sector_url(lang, s) } } },
            crumbs_ld(lang, [[sx(lang, :industries), url]])]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: lede, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  headhtml = headhtml.sub("</style>", PATTERNS_CSS + SECTORS_CSS + "</style>")
  cards = rows.map do |slug, sector, n|
    d = n["cur"].size - n["prev"].size
    arrow = d.positive? ? %(<span class="up">▲ #{d}</span>) : d.negative? ? %(<span class="down">▼ #{-d}</span>) : %(<span>= 0</span>)
    %(<a class="scard" href="#{pre(lang)}/sectors/#{slug}/"><h3>#{h(sector_name(lang, sector))}</h3><p>#{h(sx(lang, "sd_#{slug.tr('-', '_')}".to_sym))}</p>) +
      %(<div class="nums"><span>#{n['cur'].size} #{h(sx(lang, :k_cases).downcase)}</span>#{arrow}<span>#{n['warnings'].size} #{h(sx(lang, :k_warn).downcase)}</span></div></a>)
  end.join
  extra_rows = [["Individuals & consumers", sx(lang, :l_individuals)], ["Multiple / cross-sector", sx(lang, :l_multi)]].map do |sector, label|
    a = sector_numbers(incidents, warnings, sector)
    b = sector == "Multiple / cross-sector" ? sector_numbers(incidents, warnings, "Unknown") : { "cur" => [], "prev" => [], "ch" => 0 }
    [label, a["cur"].size + b["cur"].size, a["prev"].size + b["prev"].size, a["ch"] + b["ch"], nil]
  end
  table_rows = rows.map { |slug, sector, n| [%(<a href="#{pre(lang)}/sectors/#{slug}/">#{h(sector_name(lang, sector))}</a>), n["cur"].size, n["prev"].size, n["ch"], n["warnings"].size] } +
    extra_rows.map { |label, c, p, ch, w| [h(label), c, p, ch, w] }
  table = %(<table class="pt"><thead><tr><th>#{h(x(lang, :l_sector))}</th><th>#{h(sx(lang, :k_cases))}</th><th>#{h(sx(lang, :k_change, d: '±'))}</th><th>#{h(sx(lang, :k_ch))}</th><th>#{h(sx(lang, :k_warn))}</th></tr></thead><tbody>) +
    table_rows.map { |name, c, p, ch, w| d = c - p; %(<tr><td>#{name}</td><td class="n">#{c}</td><td class="n">#{d.positive? ? "+#{d}" : d}</td><td class="n">#{ch}</td><td class="n">#{w.nil? ? '—' : w}</td></tr>) }.join + "</tbody></table>"
  body = <<~HTML
    #{crumbs_html(lang, [[sx(lang, :industries), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(lede)}</p>
    <p class="winlbl">#{h(x(lang, :w12_since, date: fmt_date(WIN_FROM, lang)))}</p>
    #{share_row(lang, url, title)}
    <div class="sgrid">#{cards}</div>
    <section class="sec"><h2>#{h(sx(lang, :ind_rank_h))}</h2><p class="cap">#{h(sx(lang, :ind_rank_c))}</p><div style="overflow-x:auto">#{table}</div></section>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "sectors", headhtml, body, alternates)
end
