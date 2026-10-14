#!/usr/bin/env ruby
# frozen_string_literal: true
# Builds the crawlable, static version of the case files:
#   site/cases/<id>/index.html                 English case pages
#   site/<lang>/cases/<id>/index.html          French, Spanish, Arabic, Chinese (when a translation exists)
#   site/cases/, site/cases/category/<slug>/, site/cases/country/<cc>/   hub pages (and per language)
#   site/cases/company/<slug>/                 one hub per targeted company or product (and per language)
#   site/cases/glossary/                       plain-language definitions of the nine incident types (and per language)
#   site/about/                                method, severity scale, verified-vs-wire, licence, corrections, contact (and per language)
#   site/cases/feed.xml (+ per language)       RSS of verified case files
#   site/sitemap.xml, site/llms.txt
# Output is deterministic: same inputs give byte-identical files, so the robot
# can run it every 30 minutes without producing noise commits.
# Works on Ruby 2.6 (this Mac) and 3.3 (GitHub Actions). No gems.

require "json"
require "strscan"
require "fileutils"
require "cgi"

ROOT = File.expand_path("..", __dir__)
SITE = File.join(ROOT, "site")
BASE = "https://aithreat.io"
LANGS = %w[en fr es ar zh].freeze
RTL = %w[ar].freeze
LOCALE = { "en" => "en_US", "fr" => "fr_FR", "es" => "es_ES", "ar" => "ar_AR", "zh" => "zh_CN" }.freeze
LANG_NAME = { "en" => "English", "fr" => "Français", "es" => "Español", "ar" => "العربية", "zh" => "中文" }.freeze
UMAMI = %(<script defer src="https://cloud.umami.is/script.js" data-website-id="aafe3de7-3e98-4efd-91e0-2d01c4a8994f"></script>)
FONTS = %(<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@600;700;800&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Sans+Arabic:wght@400;500;600&family=Noto+Sans+SC:wght@400;500;600&display=swap">)
ICON = %(<link rel="icon" href="/assets/brand/favicon.svg" type="image/svg+xml"><link rel="icon" href="/assets/brand/favicon-32.png" sizes="32x32" type="image/png"><link rel="apple-touch-icon" href="/assets/brand/apple-touch-icon.png">)
OG_IMAGE = "#{BASE}/assets/brand/og-image.png"

# ---------- read the UI strings straight out of index.html (single source of truth) ----------
class JsLiteral
  def initialize(src)
    @s = StringScanner.new(src)
  end

  def parse
    ws
    value
  end

  private

  def ws
    @s.skip(%r{(?:\s+|//[^\n]*|/\*.*?\*/)+}m)
  end

  def value
    ws
    if @s.scan(/\{/) then obj
    elsif @s.scan(/\[/) then arr
    elsif @s.scan(/'/) then str("'")
    elsif @s.scan(/"/) then str('"')
    elsif (n = @s.scan(/-?\d+(?:\.\d+)?/)) then n.include?(".") ? n.to_f : n.to_i
    elsif @s.scan(/true\b/) then true
    elsif @s.scan(/false\b/) then false
    elsif @s.scan(/null\b/) then nil
    else raise "unexpected token at #{@s.pos}: #{@s.peek(40).inspect}"
    end
  end

  def obj
    h = {}
    loop do
      ws
      break if @s.scan(/\}/)
      k = if @s.scan(/'/) then str("'")
          elsif @s.scan(/"/) then str('"')
          else @s.scan(/[A-Za-z_$][\w$]*|\d+/) or raise "bad key at #{@s.pos}: #{@s.peek(40).inspect}"
          end
      ws
      @s.scan(/:/) or raise "expected ':' at #{@s.pos}"
      h[k.to_s] = value
      ws
      @s.scan(/,/)
    end
    h
  end

  def arr
    a = []
    loop do
      ws
      break if @s.scan(/\]/)
      a << value
      ws
      @s.scan(/,/)
    end
    a
  end

  def str(q)
    out = String.new
    loop do
      c = @s.getch
      raise "unterminated string" if c.nil?
      break if c == q
      if c == "\\"
        e = @s.getch
        out << case e
               when "n" then "\n"
               when "t" then "\t"
               when "u" then [@s.scan(/[0-9a-fA-F]{4}/).hex].pack("U")
               else e
               end
      else
        out << c
      end
    end
    out
  end
end

html = File.read(File.join(SITE, "index.html"), encoding: "UTF-8")
ui_start = html.index("const UI = ") or abort "build_pages: could not find `const UI = ` in site/index.html"
UI = JsLiteral.new(html[(ui_start + "const UI = ".size)..-1]).parse
abort "build_pages: UI strings missing a language" unless LANGS.all? { |l| UI[l].is_a?(Hash) }

def t(lang, key)
  v = UI[lang][key]
  v = UI["en"][key] if v.nil?
  v
end

def tt(lang, key, sub)
  d = t(lang, key)
  return d[sub] if d.is_a?(Hash) && !d[sub].nil?
  e = UI["en"][key]
  (e.is_a?(Hash) && !e[sub].nil?) ? e[sub] : sub
end

# Strings that exist only on the static pages.
EXTRA = {
  "en" => { open_map: "Open in the interactive map", permalink: "Permanent link", cite: "Cite this case", prev: "Previous case", next: "Next case",
            all_cases: "All case files", by_cat: "By type", by_country: "By country", other_langs: "This case file in other languages", verified: "Verified case file",
            licence: "Open data under CC BY 4.0: reuse freely with a link to this page.",
            index_intro: "{n} verified case files of AI security incidents, newest first. Each has a permanent link, primary sources and a ready-made citation.",
            feed_title: "AI Threat Watch: verified case files", cat_h: "{cat}: AI security incidents", country_h: "AI security incidents: {place}",
            home: "Home", cases_in: "Case files", updated: "Wire updated every 30 minutes", data: "Open data (JSON)", wire_feed: "Live wire RSS", cases_feed: "Case files RSS" },
  "fr" => { open_map: "Ouvrir dans la carte interactive", permalink: "Lien permanent", cite: "Citer ce dossier", prev: "Dossier précédent", next: "Dossier suivant",
            all_cases: "Tous les dossiers", by_cat: "Par type", by_country: "Par pays", other_langs: "Ce dossier dans d’autres langues", verified: "Dossier vérifié",
            licence: "Données ouvertes sous licence CC BY 4.0 : réutilisation libre avec un lien vers cette page.",
            index_intro: "{n} dossiers vérifiés d’incidents de sécurité de l’IA, du plus récent au plus ancien. Chacun a un lien permanent, des sources primaires et une citation prête à l’emploi.",
            feed_title: "AI Threat Watch : dossiers vérifiés", cat_h: "{cat} : incidents de sécurité de l’IA", country_h: "Incidents de sécurité de l’IA : {place}",
            home: "Accueil", cases_in: "Dossiers", updated: "Fil mis à jour toutes les 30 minutes", data: "Données ouvertes (JSON)", wire_feed: "RSS du fil", cases_feed: "RSS des dossiers" },
  "es" => { open_map: "Abrir en el mapa interactivo", permalink: "Enlace permanente", cite: "Citar este expediente", prev: "Expediente anterior", next: "Expediente siguiente",
            all_cases: "Todos los expedientes", by_cat: "Por tipo", by_country: "Por país", other_langs: "Este expediente en otros idiomas", verified: "Expediente verificado",
            licence: "Datos abiertos bajo licencia CC BY 4.0: reutilización libre con un enlace a esta página.",
            index_intro: "{n} expedientes verificados de incidentes de seguridad de la IA, del más reciente al más antiguo. Cada uno tiene un enlace permanente, fuentes primarias y una cita lista para usar.",
            feed_title: "AI Threat Watch: expedientes verificados", cat_h: "{cat}: incidentes de seguridad de la IA", country_h: "Incidentes de seguridad de la IA: {place}",
            home: "Inicio", cases_in: "Expedientes", updated: "Noticias actualizadas cada 30 minutos", data: "Datos abiertos (JSON)", wire_feed: "RSS de noticias", cases_feed: "RSS de expedientes" },
  "ar" => { open_map: "افتح في الخريطة التفاعلية", permalink: "رابط دائم", cite: "الاستشهاد بهذا الملف", prev: "الملف السابق", next: "الملف التالي",
            all_cases: "كل الملفات", by_cat: "حسب النوع", by_country: "حسب الدولة", other_langs: "هذا الملف بلغات أخرى", verified: "ملف موثّق",
            licence: "بيانات مفتوحة بترخيص CC BY 4.0: يمكن إعادة استخدامها بحرية مع رابط إلى هذه الصفحة.",
            index_intro: "{n} ملفًا موثّقًا لحوادث أمن الذكاء الاصطناعي، الأحدث أولًا. لكل ملف رابط دائم ومصادر أولية وصيغة استشهاد جاهزة.",
            feed_title: "مرصد تهديدات الذكاء الاصطناعي: الملفات الموثّقة", cat_h: "{cat}: حوادث أمن الذكاء الاصطناعي", country_h: "حوادث أمن الذكاء الاصطناعي: {place}",
            home: "الرئيسية", cases_in: "الملفات", updated: "يُحدَّث الشريط كل 30 دقيقة", data: "بيانات مفتوحة (JSON)", wire_feed: "RSS الأخبار", cases_feed: "RSS الملفات" },
  "zh" => { open_map: "在交互式地图中打开", permalink: "永久链接", cite: "引用此案例", prev: "上一个案例", next: "下一个案例",
            all_cases: "全部案例档案", by_cat: "按类型", by_country: "按国家/地区", other_langs: "此案例的其他语言版本", verified: "已核实案例档案",
            licence: "开放数据，采用 CC BY 4.0 许可：可自由再利用，请附本页链接。",
            index_intro: "{n} 份已核实的 AI 安全事件案例档案，按最新排序。每份都有永久链接、原始来源和现成的引用格式。",
            feed_title: "AI 威胁观察：已核实案例档案", cat_h: "{cat}：AI 安全事件", country_h: "{place}的 AI 安全事件",
            home: "首页", cases_in: "案例档案", updated: "新闻每 30 分钟更新", data: "开放数据（JSON）", wire_feed: "新闻 RSS", cases_feed: "案例 RSS" }
}.freeze

def x(lang, key, vars = {})
  s = EXTRA[lang][key] || EXTRA["en"][key] || key.to_s
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

COUNTRY = {
  "US" => %w[United\ States États-Unis Estados\ Unidos الولايات\ المتحدة 美国],
  "CN" => %w[China Chine China الصين 中国],
  "IT" => %w[Italy Italie Italia إيطاليا 意大利],
  "SG" => %w[Singapore Singapour Singapur سنغافورة 新加坡],
  "UA" => %w[Ukraine Ukraine Ucrania أوكرانيا 乌克兰],
  "KR" => %w[South\ Korea Corée\ du\ Sud Corea\ del\ Sur كوريا\ الجنوبية 韩国],
  "BR" => %w[Brazil Brésil Brasil البرازيل 巴西],
  "MX" => %w[Mexico Mexique México المكسيك 墨西哥],
  "IN" => %w[India Inde India الهند 印度],
  "GB" => %w[United\ Kingdom Royaume-Uni Reino\ Unido المملكة\ المتحدة 英国],
  "FR" => %w[France France Francia فرنسا 法国],
  "DE" => %w[Germany Allemagne Alemania ألمانيا 德国],
  "ES" => %w[Spain Espagne España إسبانيا 西班牙],
  "CA" => %w[Canada Canada Canadá كندا 加拿大],
  "AU" => %w[Australia Australie Australia أستراليا 澳大利亚],
  "JP" => %w[Japan Japon Japón اليابان 日本],
  "RU" => %w[Russia Russie Rusia روسيا 俄罗斯],
  "IL" => %w[Israel Israël Israel إسرائيل 以色列],
  "IR" => %w[Iran Iran Irán إيران 伊朗],
  "KP" => %w[North\ Korea Corée\ du\ Nord Corea\ del\ Norte كوريا\ الشمالية 朝鲜],
  "TW" => %w[Taiwan Taïwan Taiwán تايوان 台湾],
  "HK" => %w[Hong\ Kong Hong\ Kong Hong\ Kong هونغ\ كونغ 香港],
  "AE" => %w[United\ Arab\ Emirates Émirats\ arabes\ unis Emiratos\ Árabes\ Unidos الإمارات 阿联酋],
  "SA" => %w[Saudi\ Arabia Arabie\ saoudite Arabia\ Saudita السعودية 沙特阿拉伯],
  "NL" => %w[Netherlands Pays-Bas Países\ Bajos هولندا 荷兰],
  "SE" => %w[Sweden Suède Suecia السويد 瑞典],
  "CH" => %w[Switzerland Suisse Suiza سويسرا 瑞士],
  "PL" => %w[Poland Pologne Polonia بولندا 波兰],
  "TR" => %w[Turkey Turquie Turquía تركيا 土耳其],
  "PK" => %w[Pakistan Pakistan Pakistán باكستان 巴基斯坦],
  "ID" => %w[Indonesia Indonésie Indonesia إندونيسيا 印度尼西亚],
  "VN" => %w[Vietnam Viêt\ Nam Vietnam فيتنام 越南],
  "TH" => %w[Thailand Thaïlande Tailandia تايلاند 泰国],
  "PH" => %w[Philippines Philippines Filipinas الفلبين 菲律宾],
  "NG" => %w[Nigeria Nigeria Nigeria نيجيريا 尼日利亚],
  "ZA" => %w[South\ Africa Afrique\ du\ Sud Sudáfrica جنوب\ أفريقيا 南非],
  "EG" => %w[Egypt Égypte Egipto مصر 埃及],
  "LB" => %w[Lebanon Liban Líbano لبنان 黎巴嫩],
  "JO" => %w[Jordan Jordanie Jordania الأردن 约旦],
  "AR" => %w[Argentina Argentine Argentina الأرجنتين 阿根廷],
  "CL" => %w[Chile Chili Chile تشيلي 智利],
  "CO" => %w[Colombia Colombie Colombia كولومبيا 哥伦比亚],
  "PT" => %w[Portugal Portugal Portugal البرتغال 葡萄牙],
  "BE" => %w[Belgium Belgique Bélgica بلجيكا 比利时],
  "IE" => %w[Ireland Irlande Irlanda أيرلندا 爱尔兰],
  "AT" => %w[Austria Autriche Austria النمسا 奥地利],
  "NO" => %w[Norway Norvège Noruega النرويج 挪威],
  "DK" => %w[Denmark Danemark Dinamarca الدنمارك 丹麦],
  "FI" => %w[Finland Finlande Finlandia فنلندا 芬兰],
  "CZ" => %w[Czechia Tchéquie Chequia التشيك 捷克],
  "NZ" => %w[New\ Zealand Nouvelle-Zélande Nueva\ Zelanda نيوزيلندا 新西兰],
  "MY" => %w[Malaysia Malaisie Malasia ماليزيا 马来西亚],
  "BD" => %w[Bangladesh Bangladesh Bangladés بنغلاديش 孟加拉国],
  "KE" => %w[Kenya Kenya Kenia كينيا 肯尼亚],
  "EU" => %w[European\ Union Union\ européenne Unión\ Europea الاتحاد\ الأوروبي 欧盟]
}.freeze

def place_name(lang, cc)
  return t(lang, "ww") if cc.nil? || cc == "GL"
  row = COUNTRY[cc]
  return cc unless row
  row[LANGS.index(lang)] || row[0]
end

MONTHS = {
  "en" => %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec],
  "fr" => %w[janv. févr. mars avr. mai juin juil. août sept. oct. nov. déc.],
  "es" => %w[ene feb mar abr may jun jul ago sept oct nov dic],
  "ar" => %w[يناير فبراير مارس أبريل مايو يونيو يوليو أغسطس سبتمبر أكتوبر نوفمبر ديسمبر]
}.freeze

def fmt_date(d, lang)
  return d.to_s if d.to_s !~ /\A\d{4}-\d{2}(-\d{2})?\z/
  y, m, day = d.split("-")
  mi = m.to_i - 1
  case lang
  when "zh" then day ? "#{y}年#{m.to_i}月#{day.to_i}日" : "#{y}年#{m.to_i}月"
  when "en" then day ? "#{MONTHS['en'][mi]} #{day.to_i}, #{y}" : "#{MONTHS['en'][mi]} #{y}"
  else day ? "#{day.to_i} #{MONTHS[lang][mi]} #{y}" : "#{MONTHS[lang][mi]} #{y}"
  end
end

def fmt_usd(v)
  n, unit = if v >= 1e9 then [v / 1e9, "B"] elsif v >= 1e6 then [v / 1e6, "M"] elsif v >= 1e3 then [v / 1e3, "K"] else [v.to_f, ""] end
  s = n.round(1).to_s.sub(/\.0\z/, "")
  "$#{s}#{unit}"
end

def h(s)
  CGI.escapeHTML(s.to_s)
end

def slug(s)
  s.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
end

def pre(lang)
  lang == "en" ? "" : "/#{lang}"
end

def case_url(lang, id)
  "#{BASE}#{pre(lang)}/cases/#{id}/"
end

def present(v)
  v.is_a?(String) ? !v.strip.empty? : !v.nil?
end

# ---------- data ----------
incidents = JSON.parse(File.read(File.join(SITE, "data", "incidents.en.json"), encoding: "UTF-8"))
incidents = incidents.reject { |i| i["verified"] == false }.sort_by { |i| [i["date"].to_s, i["id"].to_s] }.reverse
TR = {}
%w[fr es ar zh].each do |l|
  p = File.join(SITE, "i18n", "#{l}.json")
  next unless File.exist?(p)
  TR[l] = {}
  JSON.parse(File.read(p, encoding: "UTF-8")).each { |e| TR[l][e["id"]] = e if e.is_a?(Hash) && e["id"] }
end

def localized(i, lang)
  return i if lang == "en"
  tr = TR[lang] && TR[lang][i["id"]]
  return nil unless tr
  o = i.merge(tr)
  if tr["timeline"].is_a?(Array)
    o["timeline"] = (i["timeline"] || []).each_with_index.map { |e, n| { "date" => e["date"], "event" => tr["timeline"][n] || e["event"] } }
  end
  o
end

# which languages each case exists in
def langs_for(i)
  LANGS.select { |l| l == "en" || (TR[l] && TR[l][i["id"]]) }
end

# ---------- page chrome ----------
CSS = <<~CSS
  :root{--bg:#0b1220;--surface:#121a2b;--surface2:#0e1627;--ink:#e6edf5;--muted:#8b9bb1;--line:#1c2740;--line2:#263450;--accent:#f5b942;--accent-ink:#0b1220;--crit:#ff5d62;--high:#ff9a4c;--med:#e0bf47;--low:#8e9aa7;--f-display:"Archivo","Arial Narrow",system-ui,sans-serif;--f-body:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",sans-serif;--f-mono:"IBM Plex Mono",ui-monospace,"SF Mono",Menlo,monospace;color-scheme:dark}
  :root[data-theme="light"]{--bg:#eef2f7;--surface:#fff;--surface2:#f6f8fb;--ink:#0f1a2b;--muted:#5b6b80;--line:#d9e0ea;--line2:#c5cfdd;--accent:#b7791f;--accent-ink:#fff;--crit:#c62828;--high:#d2691e;--med:#a08200;--low:#6a7683;color-scheme:light}
  html[lang="ar"]{--f-body:"IBM Plex Sans Arabic","IBM Plex Sans",system-ui,sans-serif;--f-display:"IBM Plex Sans Arabic",system-ui,sans-serif}
  html[lang="zh"]{--f-body:"Noto Sans SC","PingFang SC","Microsoft YaHei",system-ui,sans-serif;--f-display:"Noto Sans SC","PingFang SC",system-ui,sans-serif}
  *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 var(--f-body)}
  a{color:var(--accent)}img{max-width:100%}
  .wrap{max-width:1100px;margin:0 auto;padding:12px clamp(16px,2.5vw,32px) 48px}
  .bar{display:flex;align-items:center;gap:10px 22px;border-bottom:1px solid var(--line);padding-bottom:12px;flex-wrap:wrap}
  .brand{font-family:var(--f-display);font-weight:800;font-size:19px;letter-spacing:-.01em;text-transform:uppercase;display:inline-flex;align-items:center;gap:10px;color:var(--ink);text-decoration:none;white-space:nowrap}
  html[lang="ar"] .brand,html[lang="zh"] .brand{text-transform:none}
  .brand i{width:10px;height:10px;border-radius:50%;background:var(--crit);box-shadow:0 0 0 4px color-mix(in srgb,var(--crit) 25%,transparent)}
  nav.views{display:flex;gap:4px;flex-wrap:wrap}nav.views a{font:500 14px var(--f-body);color:var(--muted);text-decoration:none;padding:8px 14px;border-radius:999px;min-height:36px;display:inline-flex;align-items:center}
  nav.views a:hover{color:var(--ink);background:var(--surface)}nav.views a[aria-current="page"]{color:var(--accent-ink);background:var(--accent);font-weight:600}
  .bar-right{margin-inline-start:auto;display:flex;gap:6px;flex-wrap:wrap;font-size:13px}.bar-right a{color:var(--muted);text-decoration:none;padding:6px 8px;border-radius:6px}.bar-right a[aria-current]{color:var(--ink);background:var(--surface)}
  .crumbs{font:12px var(--f-mono);color:var(--muted);margin:18px 0 10px;display:flex;flex-wrap:wrap;gap:6px}.crumbs a{color:var(--muted)}
  .eyebrow{font:12px var(--f-mono);color:var(--muted);text-transform:uppercase;letter-spacing:.06em;display:flex;flex-wrap:wrap;gap:6px 14px;margin:0 0 8px}html[lang="ar"] .eyebrow,html[lang="zh"] .eyebrow{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  h1{font-family:var(--f-display);font-weight:700;font-size:clamp(26px,4vw,40px);line-height:1.1;margin:0 0 12px;letter-spacing:-.01em;text-wrap:balance}
  h2{font-family:var(--f-display);font-weight:700;font-size:19px;margin:0 0 10px}
  .lede{font-size:17px;color:var(--muted);max-width:72ch;margin:0 0 14px}
  .pills{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 16px}.pill{font:500 12px var(--f-mono);border:1px solid var(--line2);border-radius:999px;padding:3px 10px;color:var(--muted)}html[lang="ar"] .pill,html[lang="zh"] .pill{font-family:var(--f-body)}
  [data-sev="critical"]{--c:var(--crit)}[data-sev="high"]{--c:var(--high)}[data-sev="medium"]{--c:var(--med)}[data-sev="low"]{--c:var(--low)}
  .pill.sev{color:var(--c);border-color:var(--c)}
  .tools{display:flex;flex-wrap:wrap;gap:10px;margin:0 0 22px}.btn{display:inline-flex;align-items:center;min-height:38px;padding:0 16px;border-radius:8px;background:var(--accent);color:var(--accent-ink);font-weight:600;text-decoration:none}.btn.ghost{background:var(--surface);color:var(--ink);border:1px solid var(--line2)}
  .facts{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px;background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:16px;margin:0 0 22px}.facts div{min-width:0}.facts dt{font:11px var(--f-mono);text-transform:uppercase;letter-spacing:.06em;color:var(--muted)}html[lang="ar"] .facts dt,html[lang="zh"] .facts dt{font-family:var(--f-body);text-transform:none;letter-spacing:0}.facts dd{margin:3px 0 0;font-weight:500;overflow-wrap:anywhere}.facts dd.sev{color:var(--c)}
  section.sec{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:16px 18px;margin:0 0 16px}section.sec p{margin:0 0 8px;max-width:80ch}section.sec p:last-child{margin-bottom:0}.lbl{color:var(--muted)}
  .two{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px;margin:0 0 16px}.two section.sec{margin:0}
  ol.tl{list-style:none;margin:0;padding:0;display:grid;gap:8px}ol.tl li{display:grid;grid-template-columns:110px 1fr;gap:10px}ol.tl time{font:12px var(--f-mono);color:var(--muted);padding-top:3px}
  ul.srcs{margin:0;padding:0;list-style:none;display:grid;gap:6px}ul.srcs small{color:var(--muted);font-family:var(--f-mono);font-size:11px}
  pre.cite{white-space:pre-wrap;font:13px var(--f-mono);background:var(--surface2);border:1px solid var(--line);border-radius:8px;padding:12px;margin:0 0 8px;overflow-wrap:anywhere}
  nav.pn{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;margin:22px 0;font-size:14px}nav.pn a{max-width:48%;text-decoration:none;color:var(--ink);background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:10px 14px}nav.pn a span{display:block;font:11px var(--f-mono);color:var(--muted);text-transform:uppercase;letter-spacing:.06em;margin-bottom:3px}
  .langs{font-size:13px;color:var(--muted);margin:0 0 16px}.langs a{margin-inline-end:10px}
  footer{border-top:1px solid var(--line);margin-top:28px;padding-top:14px;font-size:13px;color:var(--muted);display:grid;gap:6px}footer a{color:var(--muted)}
  .notice{font-size:12px;color:var(--muted);background:var(--surface);border:1px dashed var(--line2);border-radius:6px;padding:6px 10px;margin:12px 0 0}
  ul.cases{list-style:none;margin:0;padding:0;display:grid;gap:8px}ul.cases li{display:grid;grid-template-columns:96px 1fr;gap:12px;background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px 14px}ul.cases time{font:12px var(--f-mono);color:var(--muted);padding-top:3px}ul.cases a{color:var(--ink);text-decoration:none;font-weight:600}ul.cases a:hover{color:var(--accent)}ul.cases .meta{font-size:13px;color:var(--muted);margin-top:3px}
  .chips{display:flex;flex-wrap:wrap;gap:6px;margin:0 0 18px}.chips a{font-size:13px;color:var(--ink);background:var(--surface);border:1px solid var(--line2);border-radius:999px;padding:5px 12px;text-decoration:none}.chips a[aria-current]{background:var(--accent);color:var(--accent-ink);border-color:var(--accent)}
  h3.sub{font:600 12px var(--f-mono);text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin:18px 0 8px}html[lang="ar"] h3.sub,html[lang="zh"] h3.sub{font-family:var(--f-body);text-transform:none;letter-spacing:0}
  @media (max-width:600px){ol.tl li,ul.cases li{grid-template-columns:1fr}nav.pn a{max-width:100%;flex:1}}
CSS

def head(lang:, title:, desc:, url:, alternates:, og_type: "website", jsonld: [], feed: nil)
  alts = alternates.map { |l, u| %(<link rel="alternate" hreflang="#{l}" href="#{h(u)}">) }
  alts << %(<link rel="alternate" hreflang="x-default" href="#{h(alternates['en'])}">) if alternates["en"]
  d = desc.to_s.gsub(/\s+/, " ").strip
  d = d[0, 157].sub(/\s+\S*\z/, "") + "…" if d.size > 160
  <<~HTML
    <!doctype html>
    <html lang="#{lang}"#{RTL.include?(lang) ? ' dir="rtl"' : ''}>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>#{h(title)}</title>
    <meta name="description" content="#{h(d)}">
    <link rel="canonical" href="#{h(url)}">
    #{alts.join("\n")}
    <meta property="og:type" content="#{og_type}">
    <meta property="og:site_name" content="AI Threat Watch">
    <meta property="og:title" content="#{h(title)}">
    <meta property="og:description" content="#{h(d)}">
    <meta property="og:url" content="#{h(url)}">
    <meta property="og:image" content="#{OG_IMAGE}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:locale" content="#{LOCALE[lang]}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="#{h(title)}">
    <meta name="twitter:description" content="#{h(d)}">
    <meta name="twitter:image" content="#{OG_IMAGE}">
    #{feed ? %(<link rel="alternate" type="application/rss+xml" title="#{h(x(lang, :feed_title))}" href="#{feed}">) : ''}
    <link rel="alternate" type="application/rss+xml" title="AI Threat Watch wire" href="/feed.xml">
    #{ICON}
    #{FONTS}
    <style>#{CSS}</style>
    <script>try{var t=localStorage.getItem('atw-theme');if(t)document.documentElement.setAttribute('data-theme',t)}catch(e){}</script>
    #{UMAMI}
    #{jsonld.map { |j| %(<script type="application/ld+json">#{JSON.generate(j).gsub('</', '<\/')}</script>) }.join("\n")}
    </head>
  HTML
end

def bar(lang, current)
  q = lang == "en" ? "" : "?lang=#{lang}"
  links = [["#{'/' + q}#map", t(lang, "nav_map"), "map"], ["/#{q}#wire", t(lang, "nav_wire"), "wire"], ["/#{q}#markets", t(lang, "nav_markets"), "markets"], ["/#{q}#data", t(lang, "nav_data"), "data"], ["#{pre(lang)}/cases/", x(lang, :all_cases), "cases"]]
  nav = links.map { |href, label, key| %(<a href="#{h(href)}"#{key == current ? ' aria-current="page"' : ''}>#{h(label)}</a>) }.join
  %(<div class="bar"><a class="brand" href="/#{q}"><i></i>AI Threat Watch</a><nav class="views" aria-label="Sections">#{nav}</nav><div class="bar-right" id="langbar"></div></div>)
end

def lang_links(lang, alternates)
  alternates.map { |l, u| %(<a href="#{h(u)}" hreflang="#{l}" lang="#{l}"#{l == lang ? ' aria-current="page"' : ''}>#{LANG_NAME[l]}</a>) }.join
end

def footer(lang)
  parts = []
  parts << %(<span>#{h(x(lang, :licence))}</span>)
  parts << %(<span>#{h(t(lang, 'translated'))}</span>) if lang != "en"
  parts << %(<span><a href="/data/incidents.en.json">#{h(x(lang, :data))}</a> · <a href="#{pre(lang)}/cases/feed.xml">#{h(x(lang, :cases_feed))}</a> · <a href="/feed.xml">#{h(x(lang, :wire_feed))}</a> · <a href="/sitemap.xml">Sitemap</a></span>)
  %(<footer>#{parts.join}</footer>)
end

def para(label, v, lang)
  return "" unless present(v)
  label ? %(<p><span class="lbl">#{h(label)}: </span>#{h(v)}</p>) : %(<p>#{h(v)}</p>)
end

def shell(lang, current, headhtml, body, alternates)
  html = headhtml + %(<body><div class="wrap">#{bar(lang, current)}<main>#{body}#{footer(lang)}</main></div></body></html>)
  html.sub('<div class="bar-right" id="langbar"></div>', %(<nav class="bar-right" aria-label="#{h(t(lang, 'lang'))}">#{lang_links(lang, alternates)}</nav>))
end

# ---------- case page ----------
def case_page(i_en, lang, prev_i, next_i)
  i = localized(i_en, lang)
  url = case_url(lang, i["id"])
  alternates = Hash[langs_for(i_en).map { |l| [l, case_url(l, i["id"])] }]
  place = place_name(lang, i["country"])
  cat = tt(lang, "cats", i["category"])
  sev = tt(lang, "sev", i["severity"])
  q = lang == "en" ? "" : "?lang=#{lang}"
  date_h = fmt_date(i["date"], lang)
  citation = "#{i['title']}. AI Threat Watch, #{t(lang, 'case').downcase} #{i['id']}, #{date_h}. #{url}"
  srcs = (i["sources"].is_a?(Array) && i["sources"].any? ? i["sources"] : [{ "name" => i["source"], "url" => i["url"] }]).select { |s| s["url"].to_s =~ %r{\Ahttps?://} }

  jsonld = [
    { "@context" => "https://schema.org", "@type" => "Article", "@id" => url, "mainEntityOfPage" => url,
      "headline" => i["title"], "description" => i["summary"], "datePublished" => i["date"], "inLanguage" => lang,
      "isAccessibleForFree" => true, "license" => "https://creativecommons.org/licenses/by/4.0/",
      "articleSection" => i["category"], "keywords" => [i["category"], "AI security", "AI incident", i["severity"], i["target"]].compact,
      "author" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "about" => (present(i["target"]) ? [{ "@type" => "Organization", "name" => i["target"] }] : []),
      "spatialCoverage" => place, "citation" => srcs.map { |s| s["url"] }, "image" => OG_IMAGE },
    { "@context" => "https://schema.org", "@type" => "BreadcrumbList", "itemListElement" => [
      { "@type" => "ListItem", "position" => 1, "name" => "AI Threat Watch", "item" => "#{BASE}/" },
      { "@type" => "ListItem", "position" => 2, "name" => x(lang, :all_cases), "item" => "#{BASE}#{pre(lang)}/cases/" },
      { "@type" => "ListItem", "position" => 3, "name" => cat, "item" => "#{BASE}#{pre(lang)}/cases/category/#{slug(i['category'])}/" },
      { "@type" => "ListItem", "position" => 4, "name" => i["title"], "item" => url }
    ] }
  ]
  headhtml = head(lang: lang, title: "#{i['title']} · AI Threat Watch", desc: i["summary"], url: url, alternates: alternates, og_type: "article", jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")

  facts = [
    [t(lang, "reported"), date_h, nil], [t(lang, "location"), place, nil], [t(lang, "target"), i["target"], nil], [t(lang, "severity"), sev, "sev"],
    [t(lang, "triggered_by"), i["actor"], nil], [t(lang, "actor_type"), (i["actor_type"] ? tt(lang, "actor_types", i["actor_type"]) : nil), nil],
    [t(lang, "reported_loss"), (i["loss_usd"] ? fmt_usd(i["loss_usd"]) : t(lang, "none_reported")), nil], [t(lang, "cve"), (present(i["cve"]) ? i["cve"] : t(lang, "none")), nil]
  ].map { |label, v, cls| %(<div><dt>#{h(label)}</dt><dd#{cls ? %( class="#{cls}" data-sev="#{i['severity']}") : ''}>#{h(present(v) ? v : t(lang, 'pending'))}</dd></div>) }.join

  tl = (i["timeline"] || []).map { |e| %(<li><time datetime="#{h(e['date'])}">#{h(fmt_date(e['date'], lang))}</time><span>#{h(e['event'])}</span></li>) }.join
  src_html = srcs.map do |s|
    host = (s["url"][%r{\Ahttps?://([^/]+)}, 1] || "").sub(/\Awww\./, "")
    %(<li><a href="#{h(s['url'])}" rel="noopener noreferrer nofollow" target="_blank">#{h(s['name'])}</a> <small>#{h(host)}</small></li>)
  end.join

  pn = []
  pn << %(<a href="#{h(case_url(lang, prev_i['id']))}" rel="prev"><span>← #{h(x(lang, :prev))}</span>#{h((localized(prev_i, lang) || prev_i)['title'])}</a>) if prev_i
  pn << %(<a href="#{h(case_url(lang, next_i['id']))}" rel="next"><span>#{h(x(lang, :next))} →</span>#{h((localized(next_i, lang) || next_i)['title'])}</a>) if next_i

  body = <<~HTML
    <nav class="crumbs" aria-label="Breadcrumb"><a href="/#{q}">AI Threat Watch</a> › <a href="#{pre(lang)}/cases/">#{h(x(lang, :all_cases))}</a> › <a href="#{pre(lang)}/cases/category/#{slug(i['category'])}/">#{h(cat)}</a></nav>
    <article>
    <p class="eyebrow"><span>#{h(t(lang, 'case'))} #{h(i['id'])}</span><span>#{h(cat)}</span><time datetime="#{h(i['date'])}">#{h(date_h)}</time><span><a href="#{pre(lang)}/cases/country/#{slug(i['country'] || 'gl')}/" style="color:inherit">#{h(place)}</a></span></p>
    <h1>#{h(i['title'])}</h1>
    <p class="lede">#{h(i['summary'])}</p>
    <p class="pills"><span class="pill sev" data-sev="#{i['severity']}">#{h(sev)}</span><span class="pill">#{h(i['direction'] == 'on-ai' ? t(lang, 'attack_on') : t(lang, 'attack_using'))}</span>#{present(i['status']) ? %(<span class="pill">#{h(t(lang, 'status'))}: #{h(tt(lang, 'statuses', i['status']))}</span>) : ''}<span class="pill">#{h(x(lang, :verified))}</span></p>
    <p class="tools"><a class="btn" href="/#{q}##{h(i['id'])}">#{h(x(lang, :open_map))}</a><a class="btn ghost" href="#cite">#{h(x(lang, :cite))}</a></p>
    <dl class="facts">#{facts}</dl>
    <section class="sec"><h2>#{h(t(lang, 'what'))}</h2><p>#{h(i['summary'])}</p>#{para(t(lang, 'impact'), i['impact'], lang)}</section>
    <div class="two">
      <section class="sec"><h2>#{h(t(lang, 'who'))}</h2>#{para(t(lang, 'actor'), i['actor'], lang)}#{para(t(lang, 'attribution'), i['attribution'], lang)}#{para(t(lang, 'motive'), i['motive'], lang)}</section>
      <section class="sec"><h2>#{h(t(lang, 'how'))}</h2>#{para(t(lang, 'vector'), i['vector'], lang)}#{para(t(lang, 'root_cause'), i['root_cause'], lang)}</section>
    </div>
    <div class="two">
      <section class="sec"><h2>#{h(t(lang, 'timeline'))}</h2>#{tl.empty? ? %(<p>#{h(t(lang, 'pending'))}</p>) : %(<ol class="tl">#{tl}</ol>)}</section>
      <section class="sec"><h2>#{h(t(lang, 'response'))}</h2>#{para(nil, i['response'], lang)}#{para(t(lang, 'current_status'), (present(i['status']) ? tt(lang, 'statuses', i['status']) : nil), lang)}</section>
    </div>
    <section class="sec"><h2>#{h(t(lang, 'sources'))}</h2><ul class="srcs">#{src_html}</ul></section>
    <section class="sec" id="cite"><h2>#{h(x(lang, :cite))}</h2><pre class="cite">#{h(citation)}</pre><p><span class="lbl">#{h(x(lang, :permalink))}: </span><a href="#{h(url)}">#{h(url)}</a></p></section>
    </article>
    <nav class="pn">#{pn.join}</nav>
    <p class="langs">#{h(x(lang, :other_langs))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "cases", headhtml, body, alternates)
end

# ---------- list pages (index, category, country) ----------
def list_page(items_en, lang, kind:, key: nil, all_cats: [], all_countries: [])
  path = case kind
         when :index then "#{pre(lang)}/cases/"
         when :cat then "#{pre(lang)}/cases/category/#{slug(key)}/"
         when :country then "#{pre(lang)}/cases/country/#{slug(key)}/"
         end
  url = BASE + path
  alternates = Hash[LANGS.map { |l| [l, BASE + path.sub(%r{\A#{Regexp.escape(pre(lang))}/}, "#{pre(l)}/")] }]
  title = case kind
          when :index then x(lang, :all_cases)
          when :cat then x(lang, :cat_h, cat: tt(lang, "cats", key))
          when :country then x(lang, :country_h, place: place_name(lang, key))
          end
  n = items_en.size
  intro = x(lang, :index_intro, n: n)
  jsonld = [{ "@context" => "https://schema.org", "@type" => "CollectionPage", "name" => "#{title} · AI Threat Watch", "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
              "license" => "https://creativecommons.org/licenses/by/4.0/", "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
              "mainEntity" => { "@type" => "ItemList", "numberOfItems" => n, "itemListElement" => items_en.first(100).each_with_index.map { |i, k| { "@type" => "ListItem", "position" => k + 1, "url" => case_url(lang, i["id"]), "name" => (localized(i, lang) || i)["title"] } } } }]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: intro, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")

  chips_cat = all_cats.map { |c| %(<a href="#{pre(lang)}/cases/category/#{slug(c)}/"#{kind == :cat && c == key ? ' aria-current="page"' : ''}>#{h(tt(lang, 'cats', c))}</a>) }.join
  chips_cc = all_countries.map { |c| %(<a href="#{pre(lang)}/cases/country/#{slug(c)}/"#{kind == :country && c == key ? ' aria-current="page"' : ''}>#{h(place_name(lang, c))}</a>) }.join
  rows = items_en.map do |i_en|
    i = localized(i_en, lang) || i_en
    %(<li><time datetime="#{h(i['date'])}">#{h(fmt_date(i['date'], lang))}</time><div><a href="#{h(case_url(lang, i['id']))}">#{h(i['title'])}</a><div class="meta"><span class="pill sev" data-sev="#{i['severity']}">#{h(tt(lang, 'sev', i['severity']))}</span> · #{h(tt(lang, 'cats', i['category']))} · #{h(i['target'])} · #{h(place_name(lang, i['country']))}</div></div></li>)
  end.join
  crumbs = kind == :index ? "" : %(<nav class="crumbs" aria-label="Breadcrumb"><a href="/#{lang == 'en' ? '' : '?lang=' + lang}">AI Threat Watch</a> › <a href="#{pre(lang)}/cases/">#{h(x(lang, :all_cases))}</a></nav>)
  body = <<~HTML
    #{crumbs}
    <h1 style="margin-top:#{kind == :index ? '22px' : '0'}">#{h(title)}</h1>
    <p class="lede">#{h(intro)}</p>
    <h3 class="sub">#{h(x(lang, :by_cat))}</h3><div class="chips"><a href="#{pre(lang)}/cases/"#{kind == :index ? ' aria-current="page"' : ''}>#{h(t(lang, 'ver_all'))}</a>#{chips_cat}</div>
    <h3 class="sub">#{h(x(lang, :by_country))}</h3><div class="chips">#{chips_cc}</div>
    <ul class="cases">#{rows}</ul>
  HTML
  shell(lang, "cases", headhtml, body, alternates)
end

def feed(items_en, lang)
  esc = ->(s) { s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;") }
  rss = items_en.first(50).map do |i_en|
    i = localized(i_en, lang) || i_en
    url = case_url(lang, i["id"])
    d = Time.utc(*i["date"].split("-").map(&:to_i)).strftime("%a, %d %b %Y 00:00:00 +0000") rescue i["date"]
    %(<item><title>#{esc.(i['title'])}</title><link>#{esc.(url)}</link><guid isPermaLink="true">#{esc.(url)}</guid><pubDate>#{d}</pubDate><category>#{esc.(i['category'])}</category><category>#{esc.(i['severity'])}</category><description>#{esc.(i['summary'])}</description></item>)
  end.join
  %(<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>#{esc.(x(lang, :feed_title))}</title><link>#{BASE}#{pre(lang)}/cases/</link><atom:link href="#{BASE}#{pre(lang)}/cases/feed.xml" rel="self" type="application/rss+xml"/><description>#{esc.(x(lang, :index_intro, n: items_en.size))}</description><language>#{lang}</language>#{rss}</channel></rss>\n)
end

# ---------- build ----------
cats = incidents.map { |i| i["category"] }.compact.uniq.sort
countries = incidents.map { |i| i["country"] || "GL" }.uniq.sort_by { |c| [c == "GL" ? 1 : 0, c] }

LANGS.each { |l| FileUtils.rm_rf(File.join(SITE, pre(l).sub("/", ""), "cases")) }
written = 0
write = lambda do |rel, content|
  p = File.join(SITE, rel)
  FileUtils.mkdir_p(File.dirname(p))
  File.write(p, content)
  written += 1
end

sitemap = []
add_url = lambda do |loc, alternates = nil|
  alts = alternates ? alternates.map { |l, u| %(<xhtml:link rel="alternate" hreflang="#{l}" href="#{h(u)}"/>) }.join + (alternates["en"] ? %(<xhtml:link rel="alternate" hreflang="x-default" href="#{h(alternates['en'])}"/>) : "") : ""
  sitemap << "<url><loc>#{h(loc)}</loc>#{alts}</url>"
end
add_url.("#{BASE}/")

LANGS.each do |lang|
  avail = incidents.select { |i| langs_for(i).include?(lang) }
  avail.each_with_index do |i, k|
    write.("#{pre(lang)}/cases/#{i['id']}/index.html", case_page(i, lang, (k > 0 ? avail[k - 1] : nil), avail[k + 1]))
  end
  write.("#{pre(lang)}/cases/index.html", list_page(avail, lang, kind: :index, all_cats: cats, all_countries: countries))
  cats.each { |c| write.("#{pre(lang)}/cases/category/#{slug(c)}/index.html", list_page(avail.select { |i| i['category'] == c }, lang, kind: :cat, key: c, all_cats: cats, all_countries: countries)) }
  countries.each { |c| write.("#{pre(lang)}/cases/country/#{slug(c)}/index.html", list_page(avail.select { |i| (i['country'] || 'GL') == c }, lang, kind: :country, key: c, all_cats: cats, all_countries: countries)) }
  write.("#{pre(lang)}/cases/feed.xml", feed(avail, lang))
end

# sitemap: group alternates per logical page
incidents.each { |i| add_url.(case_url("en", i["id"]), Hash[langs_for(i).map { |l| [l, case_url(l, i["id"])] }]) }
%w[fr es ar zh].each { |l| incidents.select { |i| langs_for(i).include?(l) }.each { |i| add_url.(case_url(l, i["id"]), Hash[langs_for(i).map { |m| [m, case_url(m, i["id"])] }]) } }
list_paths = ["/cases/"] + cats.map { |c| "/cases/category/#{slug(c)}/" } + countries.map { |c| "/cases/country/#{slug(c)}/" }
list_paths.each { |p| LANGS.each { |l| add_url.("#{BASE}#{pre(l)}#{p}", Hash[LANGS.map { |m| [m, "#{BASE}#{pre(m)}#{p}"] }]) } }
File.write(File.join(SITE, "sitemap.xml"), %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n#{sitemap.join("\n")}\n</urlset>\n))

# llms.txt: a plain-text map of the site for AI assistants and agents
llm = []
llm << "# AI Threat Watch"
llm << ""
llm << "> A world map and verified case files of publicly reported AI security incidents: attacks on AI systems (prompt injection, model and data leaks, AI supply chain, agent hijacks) and attacks carried out with AI (deepfake fraud, AI-assisted malware, AI phishing, state operations). A live wire of AI security news from vetted sources is refreshed every 30 minutes; verified case files are researched separately and carry a permanent link, primary sources and a citation. Case files are available in English, French, Spanish, Arabic and Chinese. All data is open under CC BY 4.0."
llm << ""
llm << "Positioning: a reference registry of AI security incidents (attacks on AI systems, and attacks carried out with AI): structured, verified, fast, multilingual and openly licensed."
llm << ""
llm << "## Key pages"
llm << "- [All verified case files](#{BASE}/cases/): #{incidents.size} incidents, newest first, with hubs by type and country"
llm << "- [Interactive world map](#{BASE}/): the same cases on a map with filters"
llm << "- [Live wire](#{BASE}/#wire): AI security headlines from vetted sources, refreshed every 30 minutes (machine-triaged, not verified)"
llm << "- [Market reaction](#{BASE}/#markets): share-price moves of listed companies after incidents (methodology on the page)"
llm << "- [Data and citing](#{BASE}/#data): download links, field list, inclusion rule, severity scale"
llm << ""
llm << "## Open data"
llm << "- [incidents.en.json](#{BASE}/data/incidents.en.json): the full verified dataset (fields: id, date, title, category, direction, severity, country, region, target, loss_usd, summary, actor, actor_type, attribution, motive, vector, root_cause, timeline, impact, response, status, cve, sources)"
llm << "- [Verified case files RSS](#{BASE}/cases/feed.xml)"
llm << "- [Live wire RSS](#{BASE}/feed.xml)"
llm << "- [Sitemap](#{BASE}/sitemap.xml)"
llm << ""
llm << "## Case files by type"
cats.each { |c| llm << "- [#{c}](#{BASE}/cases/category/#{slug(c)}/): #{incidents.count { |i| i['category'] == c }} cases" }
llm << ""
llm << "## Verified case files"
incidents.each { |i| llm << "- [#{i['title']}](#{case_url('en', i['id'])}): #{i['date']}, #{i['severity']}, #{i['category']}, #{place_name('en', i['country'])}. #{i['summary']}" }
llm << ""
llm << "## Citing"
llm << "Cite a case as: <title>. AI Threat Watch, case <id>, <date>. <permanent link>. Licence: CC BY 4.0 (reuse with a link)."
File.write(File.join(SITE, "llms.txt"), llm.join("\n") + "\n")

puts "build_pages: #{written} pages, #{sitemap.size} sitemap entries, #{incidents.size} cases, languages: #{LANGS.map { |l| "#{l}=#{incidents.count { |i| langs_for(i).include?(l) }}" }.join(' ')}"
