# Education and young people: a sector hub that states facts only, no advice. Writes
# site/education/ (per language) and site/data/education.json from the verified case files that
# involve a young person (young_people: true) or happened in a school or university (setting),
# plus editorial content in config/education.json: case studies (what happened and how schools and
# authorities responded, from the case files), prevention measures that governments, regulators,
# exam bodies and international organisations have adopted or published, and laws in force.
# Translations in config/education_i18n/<lang>.json.
# Each case keeps two separate markers so statistics stay honest: whether a young person was
# involved, and where it happened (setting: school, university, home, online).
# Loaded by build_pages.rb after build_patterns.rb; uses its helpers (head, shell, h, pre, x, t, tt,
# fmt_date, case_url, localized, crumbs_*, share_row, lang_links, hbars, stacked_bars, legend, pct).

EDU = JSON.parse(File.read(File.join(ROOT, "config", "education.json"), encoding: "UTF-8"))
EDU_I18N = Hash[LANGS.map { |l| p = File.join(ROOT, "config", "education_i18n", "#{l}.json"); [l, File.exist?(p) ? JSON.parse(File.read(p, encoding: "UTF-8")) : {}] }]
EDU_SETTINGS = %w[school university online home].freeze
EDU_AGES = %w[child teen young-adult].freeze
EDU_KINDS = %w[government regulator exams international].freeze
SETTING_COLORS = { "school" => "#f5b942", "university" => "#5b9cff", "online" => "#c084fc", "home" => "#4fd1a1", "unknown" => "#3a4760" }.freeze

EDU_CSS = <<~CSS
  .study{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:16px 18px;margin:0 0 14px}
  .study h3{margin:0 0 6px;font-size:18px}.study h3 a{color:var(--ink)}.study dl{display:grid;gap:8px;margin:10px 0 0}.study dt{font:600 11px var(--f-mono);text-transform:uppercase;letter-spacing:.05em;color:var(--muted)}.study dd{margin:0}
  html[lang="ar"] .study dt,html[lang="zh"] .study dt{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  .measures{list-style:none;padding:0;margin:0 0 14px;display:grid;gap:10px}.measures li{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
  .measures b{display:block;margin:0 0 4px}.measures small{color:var(--muted);display:block;margin:0 0 4px}
  .protect{font-size:13px;color:var(--muted);background:var(--surface);border:1px solid var(--line2);border-radius:8px;padding:10px 12px;margin:0 0 18px}
CSS

def ex(lang, key, vars = {})
  s = ((EDU_I18N[lang] || {})["ui"] || {})[key.to_s] || (EDU_I18N["en"]["ui"] || {})[key.to_s] || key.to_s
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

# Text of an editorial item (law, source) in this language, English fallback.
def edu_text(lang, kind, id, field, fallback)
  ((((EDU_I18N[lang] || {})[kind] || {})[id]) || {})[field] || fallback
end

def edu_cases(incidents)
  incidents.select { |i| i["young_people"] == true || %w[school university].include?(i["setting"]) }.sort_by { |i| i["date"].to_s }.reverse
end

def edu_stats(incidents)
  cases = edu_cases(incidents)
  young = cases.select { |i| i["young_people"] == true }
  count = ->(list, key, keys) { Hash[keys.map { |k| [k, list.count { |i| (i[key] || "unknown") == k }] }] }
  years = cases.map { |i| i["date"].to_s[0, 4] }.uniq.sort
  { "generated_at" => Time.now.utc.iso8601, "licence" => "CC BY 4.0",
    "total" => cases.size, "young_people" => young.size,
    "in_education" => cases.count { |i| %w[school university].include?(i["setting"]) },
    "countries" => cases.map { |i| i["country"] }.reject { |c| c.nil? || c == "GL" }.uniq.size,
    "critical_high" => cases.count { |i| %w[critical high].include?(i["severity"]) },
    "by_setting" => count.call(cases, "setting", EDU_SETTINGS + ["unknown"]),
    "by_age" => count.call(young, "age_group", EDU_AGES + ["unknown"]),
    "by_category" => cases.group_by { |i| i["category"] }.map { |k, v| [k, v.size] }.sort_by { |_, n| -n }.to_h,
    "by_country" => cases.group_by { |i| i["country"] || "GL" }.map { |k, v| [k, v.size] }.sort_by { |_, n| -n }.to_h,
    "years" => years, "by_year_setting" => Hash[years.map { |y| [y, count.call(cases.select { |i| i["date"].to_s[0, 4] == y }, "setting", EDU_SETTINGS + ["unknown"])] }],
    "cases" => cases.map { |i| i.slice("id", "date", "title", "category", "severity", "country", "setting", "age_group", "young_people", "response").merge("url" => case_url("en", i["id"])) },
    "case_studies" => EDU["case_studies"].map { |c| c["id"] }, "measures_in_place" => EDU["sources"], "laws" => EDU["laws"] }
end

def edu_url(lang)
  "#{BASE}#{pre(lang)}/education/"
end

def education_page(lang, st, incidents)
  url = edu_url(lang)
  alternates = Hash[LANGS.map { |l| [l, edu_url(l)] }]
  title = ex(lang, :h)
  lede = ex(lang, :lede)
  byid = Hash[incidents.map { |i| [i["id"], i] }]
  link = ->(i) { li = localized(i, lang) || i; %(<a href="#{case_url(lang, i['id'])}">#{h(li['title'])}</a>) }
  known = ->(v) { v.to_s.strip != "" && v.to_s !~ /\AUnknown\.?\z/i }
  ld = [
    { "@context" => "https://schema.org", "@type" => "Dataset", "@id" => url, "name" => title, "description" => lede, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "creator" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "distribution" => [{ "@type" => "DataDownload", "encodingFormat" => "application/json", "contentUrl" => "#{BASE}/data/education.json" }], "dateModified" => st["generated_at"][0, 10] },
    crumbs_ld(lang, [[ex(lang, :nav), url]])
  ]
  kpis = [
    [st["total"], ex(lang, :k_total)],
    [st["young_people"], ex(lang, :k_young)],
    [st["in_education"], ex(lang, :k_school)],
    [st["countries"], ex(lang, :k_countries)],
    ["#{pct(st['critical_high'], st['total'])}%", ex(lang, :k_severe)]
  ].map { |v, l| %(<div><b>#{h(v)}</b><span>#{h(l)}</span></div>) }.join
  settings = (EDU_SETTINGS + ["unknown"]).select { |s| st["by_setting"][s].to_i > 0 }
  series = settings.map { |s| [ex(lang, "set_#{s}"), SETTING_COLORS[s], st["years"].map { |y| st["by_year_setting"][y][s] }] }
  year_svg = st["years"].empty? ? "" : legend(series) + stacked_bars(st["years"], series, ex(lang, :s_year_h), hgt: 220)
  cat_html = hbars(st["by_category"].map { |c, n| [tt(lang, "cats", c), n] })
  set_html = hbars(settings.map { |s| [ex(lang, "set_#{s}"), st["by_setting"][s]] })
  age_html = hbars((EDU_AGES + ["unknown"]).select { |a| st["by_age"][a].to_i > 0 }.map { |a| [ex(lang, "age_#{a.tr('-', '_')}"), st["by_age"][a]] })
  geo_rows = st["by_country"].reject { |c, _| c == "GL" }.first(12).map { |c, n| %(<tr><td><a href="#{pre(lang)}/cases/country/#{slug(c)}/">#{h(place_name(lang, c))}</a></td><td class="n">#{n}</td></tr>) }.join
  geo_html = %(<table class="pt"><thead><tr><th>#{h(x(lang, :l_country))}</th><th>#{h(x(lang, :l_count))}</th></tr></thead><tbody>#{geo_rows}</tbody></table>)
  # Case studies: facts from the case file only (what happened, how schools and authorities responded, status).
  studies = EDU["case_studies"].map do |cs|
    i = byid[cs["id"]] or next ""
    li = localized(i, lang) || i
    fields = [[:cs_what, li["summary"]], [:cs_response, li["response"]], [:cs_status, (i["status"] ? tt(lang, "statuses", i["status"]) : nil)]].select { |_, v| known.call(v) }
    %(<article class="study"><p class="eyebrow"><span>#{h(tt(lang, 'cats', i['category']))}</span><span>#{h(place_name(lang, i['country']))}</span><time>#{h(fmt_date(i['date'], lang))}</time></p><h3>#{link.call(i)}</h3>) +
      %(<dl>#{fields.map { |k, v| %(<div><dt>#{h(ex(lang, k))}</dt><dd>#{h(v)}</dd></div>) }.join}</dl></article>)
  end.join
  # How schools and authorities responded in every school and university case, as recorded.
  responses = edu_cases(incidents).select { |i| %w[school university].include?(i["setting"]) }.map { |i| [i, (localized(i, lang) || i)["response"]] }.select { |_, r| known.call(r) }
  resp_html = %(<div style="overflow-x:auto"><table class="pt"><thead><tr><th>#{h(ex(lang, :r_case))}</th><th>#{h(ex(lang, :cs_response))}</th></tr></thead><tbody>) +
    responses.map { |i, r| %(<tr><td>#{link.call(i)} <small>#{h(place_name(lang, i['country']))}, #{h(i['date'][0, 4])}</small></td><td>#{h(r)}</td></tr>) }.join + "</tbody></table></div>"
  # Measures in place: what governments, regulators, exam bodies and international organisations adopted or published.
  measures = EDU_KINDS.map do |k|
    ms = EDU["sources"].select { |s| s["kind"] == k }
    next "" if ms.empty?
    items = ms.map do |s|
      %(<li><small>#{h(s['organisation'])} · #{h(s['country_or_scope'])} · #{h(s['year'])}</small><b><a href="#{h(s['url'])}" rel="noopener" target="_blank">#{h(s['title'])}</a></b><span>#{h(edu_text(lang, 'sources', s['id'], 'summary', s['summary']))}</span></li>)
    end.join
    %(<h3>#{h(ex(lang, "kind_#{k}"))}</h3><ul class="measures">#{items}</ul>)
  end.join
  laws = %(<table class="pt"><thead><tr><th>#{h(x(lang, :l_country))}</th><th>#{h(ex(lang, :l_law))}</th><th>#{h(ex(lang, :l_does))}</th></tr></thead><tbody>) +
    EDU["laws"].map { |lw| %(<tr><td>#{h(lw['country'])}</td><td><a href="#{h(lw['url'])}" rel="noopener" target="_blank">#{h(lw['law'])}</a> (#{h(lw['year'])})</td><td>#{h(edu_text(lang, 'laws', lw['id'], 'what_it_does', lw['what_it_does']))}</td></tr>) }.join + "</tbody></table>"
  list = %(<ul class="cases auto">#{edu_cases(incidents).map { |i| %(<li><time>#{h(fmt_date(i['date'], lang))}</time><span>#{link.call(i)} <small>· #{h(ex(lang, "set_#{i['setting'] || 'unknown'}"))}</small></span></li>) }.join}</ul>)
  body = <<~HTML
    #{crumbs_html(lang, [[ex(lang, :nav), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(lede)}</p>
    #{share_row(lang, url, title)}
    <p class="protect">#{h(ex(lang, :protect))}</p>
    <div class="kpis">#{kpis}</div>
    <section class="sec"><h2>#{h(ex(lang, :s_year_h))}</h2>#{year_svg}<p class="cap">#{h(ex(lang, :s_year_c))}</p></section>
    <div class="two">
      <section class="sec"><h2>#{h(ex(lang, :s_cat_h))}</h2>#{cat_html}</section>
      <section class="sec"><h2>#{h(ex(lang, :s_set_h))}</h2>#{set_html}<h2>#{h(ex(lang, :s_age_h))}</h2>#{age_html}</section>
    </div>
    <section class="sec"><h2>#{h(ex(lang, :s_geo_h))}</h2>#{geo_html}<p class="cap">#{h(ex(lang, :s_geo_c))}</p></section>
    <section class="sec" id="case-studies"><h2>#{h(ex(lang, :cs_h))}</h2><p class="cap">#{h(ex(lang, :cs_c))}</p>#{studies}</section>
    <section class="sec" id="responses"><h2>#{h(ex(lang, :r_h))}</h2><p class="cap">#{h(ex(lang, :r_c, n: responses.size))}</p>#{resp_html}</section>
    <section class="sec" id="measures"><h2>#{h(ex(lang, :prev_h))}</h2><p class="cap">#{h(ex(lang, :prev_c))}</p>#{measures}</section>
    <section class="sec" id="laws"><h2>#{h(ex(lang, :laws_h))}</h2><p class="cap">#{h(ex(lang, :laws_c))}</p><div style="overflow-x:auto">#{laws}</div></section>
    <section class="sec" id="cases"><h2>#{h(ex(lang, :all_h, n: st['total']))}</h2>#{list}</section>
    <p class="method">#{h(ex(lang, :method))} <a href="/data/education.json">education.json (CC BY 4.0)</a></p>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  html = head(lang: lang, title: "#{title} · AI Threat Watch", desc: lede, url: url, alternates: alternates, jsonld: ld, feed: "#{pre(lang)}/cases/feed.xml")
  shell(lang, "education", html.sub("</style>", PATTERNS_CSS + EDU_CSS + "</style>"), body, alternates)
end
