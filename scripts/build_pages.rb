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
#   site/cases/<old-id>/index.html             redirect pages for merged case files (config/redirects.json, and per language)
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
}

# Strings for the company hubs, the glossary and the about page (merged into EXTRA below).
MORE = {
  "en" => { by_company: "By company", company_h: "AI security incidents: {company}", company_intro: "{n} verified case files in which {company} was the target or the platform abused, newest first. Each has a permanent link, primary sources and a ready-made citation.",
            company_intro_1: "1 verified case file in which {company} was the target or the platform abused. It has a permanent link, primary sources and a ready-made citation.",
            glossary: "Glossary", glossary_h: "Glossary of AI security incident types", glossary_intro: "Plain-language definitions of the nine types used to classify every case file on this site, with a link to the cases of each type.", glossary_cases: "{n} case files", glossary_see: "See the cases",
            about: "About & method", about_h: "About AI Threat Watch: method, licence and corrections",
            about_intro: "AI Threat Watch is a reference registry of publicly reported AI security incidents: attacks on AI systems and attacks carried out with AI. This page explains what gets in, how it is rated, what is verified, how to reuse the data and how errors are corrected.",
            about_wire_h: "Verified case files and the live wire are different things",
            about_wire_p1: "The wire is a feed of AI security headlines from vetted sources, refreshed every 30 minutes and sorted by a machine. Nothing on the wire is verified: it shows what is being reported, not what has been confirmed.",
            about_wire_p2: "Case files are reviewed before publication. Each has a permanent link, names its primary sources and records attribution as the source stated it. When a file was first drafted by a machine from a news report, it is labelled as unverified and auto-drafted until an editor has checked it, and it gets no static page and no entry in the case files feed until then.",
            about_langs: "Case files are published in English, French, Spanish, Arabic and Chinese. The English version is the reference; translations are machine-translated and reviewed for terminology.",
            sev_critical: "Confirmed breaches with large-scale data theft, active exploitation in the wild, or state operations.", sev_high: "Confirmed compromise or fraud with material loss.", sev_medium: "Demonstrated flaws fixed before abuse, or limited exposures.", sev_low: "Proofs of concept.",
            about_lic_h: "Licence and citation",
            about_lic_p: "The dataset, the case files and the translations are published under the Creative Commons Attribution 4.0 licence (CC BY 4.0). You may copy, redistribute and build on them for any purpose, including commercially, as long as you credit AI Threat Watch and link to the page you used.",
            cite_fmt: "<title>. AI Threat Watch, {case} <id>, <date>. <permanent link>", cite_example: "Example",
            about_corr_h: "Corrections", about_corr_p: "Case files are edited in the open. Every change to a case file is recorded in a public change log with its date and content; nothing is deleted or rewritten silently. When a fact turns out to be wrong, the file is corrected and the correction stays visible in the log.", changelog: "Public change log",
            about_contact_h: "Contact", about_contact_p: "You can also open an issue on the project's GitHub repository.", github_issues: "Report on GitHub" },
  "fr" => { by_company: "Par entreprise", company_h: "Incidents de sécurité de l’IA : {company}", company_intro: "{n} dossiers vérifiés dans lesquels {company} était la cible ou la plateforme détournée, du plus récent au plus ancien. Chacun a un lien permanent, des sources primaires et une citation prête à l’emploi.",
            company_intro_1: "1 dossier vérifié dans lequel {company} était la cible ou la plateforme détournée. Il a un lien permanent, des sources primaires et une citation prête à l’emploi.",
            glossary: "Glossaire", glossary_h: "Glossaire des types d’incidents de sécurité de l’IA", glossary_intro: "Définitions en langage clair des neuf types utilisés pour classer chaque dossier de ce site, avec un lien vers les dossiers de chaque type.", glossary_cases: "{n} dossiers", glossary_see: "Voir les dossiers",
            about: "À propos et méthode", about_h: "À propos d’AI Threat Watch : méthode, licence et corrections",
            about_intro: "AI Threat Watch est un registre de référence des incidents de sécurité de l’IA signalés publiquement : attaques contre des systèmes d’IA et attaques menées avec l’IA. Cette page explique ce qui est retenu, comment c’est évalué, ce qui est vérifié, comment réutiliser les données et comment les erreurs sont corrigées.",
            about_wire_h: "Les dossiers vérifiés et le fil en direct sont deux choses différentes",
            about_wire_p1: "Le fil est un flux de titres sur la sécurité de l’IA issus de sources sélectionnées, actualisé toutes les 30 minutes et trié par une machine. Rien sur le fil n’est vérifié : il montre ce qui est rapporté, pas ce qui est confirmé.",
            about_wire_p2: "Les dossiers sont relus avant publication. Chacun a un lien permanent, nomme ses sources primaires et rapporte l’attribution telle que la source l’a formulée. Lorsqu’un dossier a d’abord été rédigé par une machine à partir d’un article, il est signalé comme non vérifié et rédigé automatiquement jusqu’à ce qu’un éditeur l’ait contrôlé ; il n’a ni page statique ni entrée dans le flux des dossiers avant cela.",
            about_langs: "Les dossiers sont publiés en anglais, français, espagnol, arabe et chinois. La version anglaise fait référence ; les traductions sont automatiques et relues pour la terminologie.",
            sev_critical: "Intrusions confirmées avec vol massif de données, exploitation active ou opérations étatiques.", sev_high: "Compromission ou fraude confirmée avec perte matérielle.", sev_medium: "Failles démontrées, corrigées avant abus, ou expositions limitées.", sev_low: "Preuves de concept.",
            about_lic_h: "Licence et citation",
            about_lic_p: "Le jeu de données, les dossiers et les traductions sont publiés sous licence Creative Commons Attribution 4.0 (CC BY 4.0). Vous pouvez les copier, les redistribuer et les réutiliser à toute fin, y compris commerciale, à condition de créditer AI Threat Watch et de renvoyer vers la page utilisée.",
            cite_fmt: "<titre>. AI Threat Watch, {case} <id>, <date>. <lien permanent>", cite_example: "Exemple",
            about_corr_h: "Corrections", about_corr_p: "Les dossiers sont modifiés au grand jour. Chaque changement est consigné dans un journal public des modifications avec sa date et son contenu ; rien n’est supprimé ni réécrit en silence. Lorsqu’un fait s’avère faux, le dossier est corrigé et la correction reste visible dans le journal.", changelog: "Journal public des modifications",
            about_contact_h: "Contact", about_contact_p: "Vous pouvez aussi ouvrir un ticket sur le dépôt GitHub du projet.", github_issues: "Signaler sur GitHub" },
  "es" => { by_company: "Por empresa", company_h: "Incidentes de seguridad de la IA: {company}", company_intro: "{n} expedientes verificados en los que {company} fue el objetivo o la plataforma abusada, del más reciente al más antiguo. Cada uno tiene un enlace permanente, fuentes primarias y una cita lista para usar.",
            company_intro_1: "1 expediente verificado en el que {company} fue el objetivo o la plataforma abusada. Tiene un enlace permanente, fuentes primarias y una cita lista para usar.",
            glossary: "Glosario", glossary_h: "Glosario de tipos de incidentes de seguridad de la IA", glossary_intro: "Definiciones en lenguaje claro de los nueve tipos usados para clasificar cada expediente de este sitio, con un enlace a los casos de cada tipo.", glossary_cases: "{n} expedientes", glossary_see: "Ver los expedientes",
            about: "Acerca de y método", about_h: "Acerca de AI Threat Watch: método, licencia y correcciones",
            about_intro: "AI Threat Watch es un registro de referencia de incidentes de seguridad de la IA reportados públicamente: ataques contra sistemas de IA y ataques realizados con IA. Esta página explica qué se incluye, cómo se califica, qué está verificado, cómo reutilizar los datos y cómo se corrigen los errores.",
            about_wire_h: "Los expedientes verificados y las noticias en vivo son cosas distintas",
            about_wire_p1: "Las noticias son un flujo de titulares sobre seguridad de la IA de fuentes seleccionadas, actualizado cada 30 minutos y ordenado por una máquina. Nada en ese flujo está verificado: muestra lo que se reporta, no lo que se ha confirmado.",
            about_wire_p2: "Los expedientes se revisan antes de publicarse. Cada uno tiene un enlace permanente, nombra sus fuentes primarias y registra la atribución tal como la expresó la fuente. Cuando un expediente fue redactado primero por una máquina a partir de una noticia, se marca como no verificado y redactado automáticamente hasta que un editor lo comprueba, y hasta entonces no tiene página estática ni entrada en el RSS de expedientes.",
            about_langs: "Los expedientes se publican en inglés, francés, español, árabe y chino. La versión inglesa es la de referencia; las traducciones son automáticas y revisadas en su terminología.",
            sev_critical: "Intrusiones confirmadas con robo masivo de datos, explotación activa u operaciones estatales.", sev_high: "Compromiso o fraude confirmado con pérdida material.", sev_medium: "Fallos demostrados, corregidos antes de ser abusados, o exposiciones limitadas.", sev_low: "Pruebas de concepto.",
            about_lic_h: "Licencia y cita",
            about_lic_p: "El conjunto de datos, los expedientes y las traducciones se publican bajo la licencia Creative Commons Atribución 4.0 (CC BY 4.0). Puede copiarlos, redistribuirlos y reutilizarlos con cualquier fin, incluso comercial, siempre que acredite a AI Threat Watch y enlace a la página utilizada.",
            cite_fmt: "<título>. AI Threat Watch, {case} <id>, <fecha>. <enlace permanente>", cite_example: "Ejemplo",
            about_corr_h: "Correcciones", about_corr_p: "Los expedientes se editan a la vista de todos. Cada cambio queda registrado en un historial público con su fecha y contenido; nada se borra ni se reescribe en silencio. Cuando un dato resulta erróneo, el expediente se corrige y la corrección sigue visible en el historial.", changelog: "Historial público de cambios",
            about_contact_h: "Contacto", about_contact_p: "También puede abrir un issue en el repositorio GitHub del proyecto.", github_issues: "Reportar en GitHub" },
  "ar" => { by_company: "حسب الشركة", company_h: "حوادث أمن الذكاء الاصطناعي: {company}", company_intro: "{n} ملفًا موثّقًا كانت فيه {company} الهدف أو المنصة المُستغلة، الأحدث أولًا. لكل ملف رابط دائم ومصادر أولية وصيغة استشهاد جاهزة.",
            company_intro_1: "ملف موثّق واحد كانت فيه {company} الهدف أو المنصة المُستغلة. له رابط دائم ومصادر أولية وصيغة استشهاد جاهزة.",
            glossary: "المصطلحات", glossary_h: "مسرد أنواع حوادث أمن الذكاء الاصطناعي", glossary_intro: "تعريفات بلغة واضحة للأنواع التسعة المستخدمة لتصنيف كل ملف في هذا الموقع، مع رابط إلى حالات كل نوع.", glossary_cases: "{n} ملفًا", glossary_see: "عرض الملفات",
            about: "عن الموقع والمنهجية", about_h: "عن مرصد تهديدات الذكاء الاصطناعي: المنهجية والترخيص والتصحيحات",
            about_intro: "مرصد تهديدات الذكاء الاصطناعي سجل مرجعي لحوادث أمن الذكاء الاصطناعي المُعلنة: هجمات على أنظمة الذكاء الاصطناعي وهجمات نُفِّذت باستخدامه. تشرح هذه الصفحة ما يُدرج، وكيف يُقيَّم، وما هو موثّق، وكيف تُعاد استخدام البيانات، وكيف تُصحَّح الأخطاء.",
            about_wire_h: "الملفات الموثّقة وشريط الأخبار شيئان مختلفان",
            about_wire_p1: "شريط الأخبار تدفق من عناوين أمن الذكاء الاصطناعي من مصادر مختارة، يُحدَّث كل 30 دقيقة وتصنّفه آلة. لا شيء في الشريط موثّق: فهو يعرض ما يُنشر، لا ما تأكّد.",
            about_wire_p2: "تُراجَع الملفات قبل نشرها. لكل ملف رابط دائم، ويذكر مصادره الأولية، ويسجّل الإسناد كما ذكره المصدر. وعندما تصوغ آلة الملف أولًا من خبر صحفي، يُوسم بأنه غير موثّق ومُعدّ آليًا حتى يتحقق منه محرر، ولا تُنشأ له صفحة ثابتة ولا يظهر في خلاصة الملفات قبل ذلك.",
            about_langs: "تُنشر الملفات بالإنجليزية والفرنسية والإسبانية والعربية والصينية. النسخة الإنجليزية هي المرجع؛ والترجمات آلية ومُراجَعة من حيث المصطلحات.",
            sev_critical: "اختراقات مؤكدة مع سرقة بيانات واسعة، أو استغلال نشط، أو عمليات دول.", sev_high: "اختراق أو احتيال مؤكد مع خسارة مادية.", sev_medium: "ثغرات مثبتة أُصلحت قبل استغلالها، أو تعرضات محدودة.", sev_low: "إثباتات مفهوم.",
            about_lic_h: "الترخيص والاستشهاد",
            about_lic_p: "تُنشر مجموعة البيانات والملفات والترجمات بترخيص المشاع الإبداعي نسب المصنف 4.0 (CC BY 4.0). يمكنك نسخها وإعادة توزيعها والبناء عليها لأي غرض، بما في ذلك التجاري، بشرط الإشارة إلى مرصد تهديدات الذكاء الاصطناعي ووضع رابط إلى الصفحة المستخدمة.",
            cite_fmt: "<العنوان>. AI Threat Watch, {case} <المعرّف>, <التاريخ>. <الرابط الدائم>", cite_example: "مثال",
            about_corr_h: "التصحيحات", about_corr_p: "تُحرَّر الملفات على الملأ. يُسجَّل كل تغيير في سجل تغييرات عام مع تاريخه ومحتواه؛ ولا يُحذف شيء ولا يُعاد كتابته في صمت. وعندما يتبيّن خطأ في معلومة، يُصحَّح الملف ويبقى التصحيح ظاهرًا في السجل.", changelog: "سجل التغييرات العام",
            about_contact_h: "التواصل", about_contact_p: "يمكنك أيضًا فتح بلاغ في مستودع المشروع على GitHub.", github_issues: "الإبلاغ عبر GitHub" },
  "zh" => { by_company: "按公司", company_h: "{company}的 AI 安全事件", company_intro: "{n} 份已核实的案例档案，其中 {company} 是目标或被滥用的平台，按最新排序。每份都有永久链接、原始来源和现成的引用格式。",
            company_intro_1: "1 份已核实的案例档案，其中 {company} 是目标或被滥用的平台。它有永久链接、原始来源和现成的引用格式。",
            glossary: "术语表", glossary_h: "AI 安全事件类型术语表", glossary_intro: "本站用于分类每份案例档案的九种类型的通俗定义，并附每种类型案例的链接。", glossary_cases: "{n} 份案例档案", glossary_see: "查看案例",
            about: "关于与方法", about_h: "关于 AI 威胁观察：方法、许可与更正",
            about_intro: "AI 威胁观察是公开报道的 AI 安全事件的参考登记册：针对 AI 系统的攻击，以及利用 AI 实施的攻击。本页说明收录标准、评级方式、核实范围、数据再利用方式以及错误的更正方式。",
            about_wire_h: "已核实案例档案与实时新闻是两回事",
            about_wire_p1: "新闻流汇集来自精选来源的 AI 安全头条，每 30 分钟更新一次，由机器分类。新闻流中的内容均未经核实：它显示的是正在被报道的内容，而不是已确认的事实。",
            about_wire_p2: "案例档案在发布前经过审核。每份都有永久链接、注明原始来源，并按来源的表述记录归因。若档案最初由机器根据新闻报道起草，在编辑核查之前会标记为“未核实 · 自动起草”，且在此之前不会生成静态页面，也不会进入案例 RSS。",
            about_langs: "案例档案以英文、法文、西班牙文、阿拉伯文和中文发布。英文版为参考版本；译文由机器翻译并经过术语审校。",
            sev_critical: "确认的入侵并伴有大规模数据窃取、在野利用或国家行动。", sev_high: "确认的入侵或欺诈并造成实质损失。", sev_medium: "已演示的漏洞、在被滥用前修复，或影响有限的暴露。", sev_low: "概念验证。",
            about_lic_h: "许可与引用",
            about_lic_p: "数据集、案例档案和译文均采用知识共享署名 4.0 许可（CC BY 4.0）发布。您可以出于任何目的（包括商业目的）复制、再分发和改编，只需注明 AI 威胁观察并链接到所使用的页面。",
            cite_fmt: "<标题>. AI Threat Watch, {case} <id>, <日期>. <永久链接>", cite_example: "示例",
            about_corr_h: "更正", about_corr_p: "案例档案公开编辑。每次修改都记录在公开的更改日志中，包含日期和内容；不会悄悄删除或改写任何内容。若某项事实被证明有误，档案会被更正，更正记录在日志中保持可见。", changelog: "公开更改日志",
            about_contact_h: "联系", about_contact_p: "您也可以在项目的 GitHub 仓库中提交 issue。", github_issues: "在 GitHub 上报告" }
}
LANGS.each { |l| EXTRA[l] = EXTRA[l].merge(MORE[l]) }
EXTRA.freeze
REPO = "https://github.com/karlabouzeid/aithreat"
CHANGELOG_URL = "#{REPO}/commits/main/site/data/incidents.en.json"
ISSUES_URL = "#{REPO}/issues"

# Glossary: one plain-language definition per category, keyed by the English category name used in the data.
GLOSSARY = {
  "en" => {
    "Prompt injection" => "Prompt injection is an attack in which text that an AI model reads, such as a web page, a document or an email, contains instructions that the model follows as if they came from its user or operator. It can make an assistant leak data, take unwanted actions or ignore its safety rules. It is the most common class of attack on systems built on large language models.",
    "Deepfake fraud" => "Deepfake fraud uses AI-generated voice, video or images to impersonate a real person, usually an executive, a relative or a public figure, in order to deceive a victim. Typical cases are fake video calls that authorise payments and cloned voices used in scam calls. Losses are often reported by police or courts rather than by the victim.",
    "AI-assisted malware" => "AI-assisted malware is malicious software written, adapted or operated with the help of AI models. This covers code generated by assistants, malware that calls a model at run time to decide its next step, and criminal toolkits built on language models. The AI lowers the skill and time needed to produce working attack code.",
    "AI supply chain" => "An AI supply chain incident compromises a component that AI systems depend on: a model file, a dataset, a developer tool, an extension, a package registry or a hosting platform. One malicious or vulnerable component can reach every project that installs it. Cases include poisoned packages, backdoored models and compromised coding assistants.",
    "Model & data leak" => "A model and data leak exposes information held by an AI system: user conversations, API keys, training data, model weights or internal configuration. Causes range from misconfigured databases and storage to flaws in the application around the model. The harm is measured by what was exposed and for how long.",
    "LLMjacking" => "LLMjacking is the theft of access to paid AI models, usually through stolen cloud credentials or API keys. Attackers run their own workloads or resell the access while the victim receives the bill. It is the AI equivalent of cryptojacking.",
    "Agent hijack" => "An agent hijack takes control of an AI agent, a model given tools such as a browser, a shell, email or payment systems, and makes it act against its owner. The entry point is often prompt injection or a compromised tool, and the agent's permissions become the attacker's. Damage includes deleted files, leaked data and unauthorised actions taken automatically.",
    "AI phishing" => "AI phishing uses language models to write, translate and personalise fraudulent messages at scale, or to build fake sites and chatbots that harvest credentials. The text is fluent and tailored, so traditional warning signs such as spelling mistakes disappear. Cases include campaigns against officials, companies and consumers.",
    "State actor AI ops" => "State actor AI operations are the use of AI by government-linked groups for espionage, influence campaigns or cyberattacks. Reports come mostly from AI providers that detect and disrupt the accounts involved, and from government agencies. Attribution is recorded as the source stated it, with its confidence level."
  },
  "fr" => {
    "Prompt injection" => "L’injection de prompt est une attaque dans laquelle un texte lu par un modèle d’IA, comme une page web, un document ou un e-mail, contient des instructions que le modèle suit comme si elles venaient de son utilisateur ou de son opérateur. Elle peut amener un assistant à divulguer des données, à agir à l’insu de l’utilisateur ou à ignorer ses règles de sécurité. C’est la classe d’attaque la plus fréquente contre les systèmes fondés sur de grands modèles de langage.",
    "Deepfake fraud" => "La fraude par deepfake utilise une voix, une vidéo ou des images générées par l’IA pour se faire passer pour une personne réelle, le plus souvent un dirigeant, un proche ou une personnalité publique, afin de tromper une victime. Les cas typiques sont de faux appels vidéo qui autorisent des paiements et des voix clonées utilisées dans des appels frauduleux. Les pertes sont souvent rapportées par la police ou les tribunaux plutôt que par la victime.",
    "AI-assisted malware" => "Un malware assisté par IA est un logiciel malveillant écrit, adapté ou piloté avec l’aide de modèles d’IA. Cela couvre le code généré par des assistants, les malwares qui interrogent un modèle à l’exécution pour décider de l’étape suivante et les boîtes à outils criminelles bâties sur des modèles de langage. L’IA réduit les compétences et le temps nécessaires pour produire un code d’attaque fonctionnel.",
    "AI supply chain" => "Un incident de chaîne d’approvisionnement IA compromet un composant dont dépendent les systèmes d’IA : un fichier de modèle, un jeu de données, un outil de développement, une extension, un registre de paquets ou une plateforme d’hébergement. Un seul composant malveillant ou vulnérable peut atteindre tous les projets qui l’installent. Les cas incluent des paquets empoisonnés, des modèles piégés et des assistants de programmation compromis.",
    "Model & data leak" => "Une fuite de modèle et de données expose des informations détenues par un système d’IA : conversations des utilisateurs, clés d’API, données d’entraînement, poids du modèle ou configuration interne. Les causes vont des bases de données et stockages mal configurés aux failles de l’application qui entoure le modèle. Le préjudice se mesure à ce qui a été exposé et pendant combien de temps.",
    "LLMjacking" => "Le LLMjacking est le vol d’accès à des modèles d’IA payants, généralement via des identifiants cloud ou des clés d’API dérobés. Les attaquants exécutent leurs propres traitements ou revendent l’accès pendant que la victime reçoit la facture. C’est l’équivalent pour l’IA du cryptojacking.",
    "Agent hijack" => "Le détournement d’agent prend le contrôle d’un agent d’IA, c’est-à-dire un modèle doté d’outils tels qu’un navigateur, un terminal, une messagerie ou des systèmes de paiement, et le fait agir contre son propriétaire. Le point d’entrée est souvent une injection de prompt ou un outil compromis, et les permissions de l’agent deviennent celles de l’attaquant. Les dégâts vont de fichiers supprimés à des données divulguées et à des actions non autorisées exécutées automatiquement.",
    "AI phishing" => "L’hameçonnage par IA utilise des modèles de langage pour rédiger, traduire et personnaliser des messages frauduleux à grande échelle, ou pour créer de faux sites et chatbots qui collectent des identifiants. Le texte est fluide et ciblé, de sorte que les signaux d’alerte habituels comme les fautes d’orthographe disparaissent. Les cas incluent des campagnes visant des responsables publics, des entreprises et des consommateurs.",
    "State actor AI ops" => "Les opérations étatiques avec l’IA désignent l’usage de l’IA par des groupes liés à des gouvernements pour l’espionnage, les campagnes d’influence ou les cyberattaques. Les signalements viennent surtout des fournisseurs d’IA qui détectent et neutralisent les comptes concernés, et d’agences gouvernementales. L’attribution est rapportée telle que la source l’a formulée, avec son niveau de confiance."
  },
  "es" => {
    "Prompt injection" => "La inyección de prompts es un ataque en el que un texto que lee un modelo de IA, como una página web, un documento o un correo, contiene instrucciones que el modelo sigue como si vinieran de su usuario u operador. Puede hacer que un asistente filtre datos, realice acciones no deseadas o ignore sus reglas de seguridad. Es la clase de ataque más común contra sistemas basados en grandes modelos de lenguaje.",
    "Deepfake fraud" => "El fraude con deepfakes usa voz, vídeo o imágenes generadas por IA para hacerse pasar por una persona real, normalmente un directivo, un familiar o una figura pública, con el fin de engañar a una víctima. Los casos típicos son videollamadas falsas que autorizan pagos y voces clonadas usadas en llamadas fraudulentas. Las pérdidas suelen ser reportadas por la policía o los tribunales más que por la víctima.",
    "AI-assisted malware" => "El malware asistido por IA es software malicioso escrito, adaptado u operado con ayuda de modelos de IA. Incluye código generado por asistentes, malware que consulta un modelo en tiempo de ejecución para decidir su siguiente paso y kits criminales construidos sobre modelos de lenguaje. La IA reduce la habilidad y el tiempo necesarios para producir código de ataque funcional.",
    "AI supply chain" => "Un incidente de cadena de suministro de IA compromete un componente del que dependen los sistemas de IA: un archivo de modelo, un conjunto de datos, una herramienta de desarrollo, una extensión, un registro de paquetes o una plataforma de alojamiento. Un solo componente malicioso o vulnerable puede alcanzar a todos los proyectos que lo instalan. Los casos incluyen paquetes envenenados, modelos con puertas traseras y asistentes de programación comprometidos.",
    "Model & data leak" => "Una filtración de modelos y datos expone información que guarda un sistema de IA: conversaciones de usuarios, claves de API, datos de entrenamiento, pesos del modelo o configuración interna. Las causas van desde bases de datos y almacenamiento mal configurados hasta fallos en la aplicación que rodea al modelo. El daño se mide por lo que quedó expuesto y durante cuánto tiempo.",
    "LLMjacking" => "El LLMjacking es el robo de acceso a modelos de IA de pago, normalmente mediante credenciales de nube o claves de API robadas. Los atacantes ejecutan sus propias cargas de trabajo o revenden el acceso mientras la víctima recibe la factura. Es el equivalente en IA del cryptojacking.",
    "Agent hijack" => "El secuestro de agentes toma el control de un agente de IA, es decir, un modelo dotado de herramientas como un navegador, una terminal, correo o sistemas de pago, y lo hace actuar contra su propietario. El punto de entrada suele ser una inyección de prompts o una herramienta comprometida, y los permisos del agente pasan a ser los del atacante. Los daños incluyen archivos borrados, datos filtrados y acciones no autorizadas ejecutadas automáticamente.",
    "AI phishing" => "El phishing con IA usa modelos de lenguaje para redactar, traducir y personalizar mensajes fraudulentos a gran escala, o para construir sitios y chatbots falsos que recolectan credenciales. El texto es fluido y a medida, por lo que desaparecen las señales de alerta tradicionales como las faltas de ortografía. Los casos incluyen campañas contra funcionarios, empresas y consumidores.",
    "State actor AI ops" => "Las operaciones estatales con IA son el uso de IA por grupos vinculados a gobiernos para espionaje, campañas de influencia o ciberataques. Los reportes proceden sobre todo de proveedores de IA que detectan y desactivan las cuentas implicadas, y de agencias gubernamentales. La atribución se registra tal como la expresó la fuente, con su nivel de confianza."
  },
  "ar" => {
    "Prompt injection" => "حقن الأوامر هجوم يتضمّن فيه نص يقرأه نموذج ذكاء اصطناعي، مثل صفحة ويب أو مستند أو بريد إلكتروني، تعليمات ينفّذها النموذج كما لو كانت من مستخدمه أو مشغّله. قد يدفع المساعد إلى تسريب بيانات أو تنفيذ إجراءات غير مرغوبة أو تجاهل قواعد السلامة. وهو أكثر فئات الهجوم شيوعًا على الأنظمة المبنية على نماذج اللغة الكبيرة.",
    "Deepfake fraud" => "يستخدم الاحتيال بالتزييف العميق صوتًا أو فيديو أو صورًا مولّدة بالذكاء الاصطناعي لانتحال شخصية حقيقية، غالبًا مدير تنفيذي أو قريب أو شخصية عامة، بهدف خداع الضحية. من الحالات النموذجية مكالمات فيديو مزيفة تُجيز دفعات مالية وأصوات مستنسخة تُستخدم في مكالمات نصب. وغالبًا ما تُعلن الخسائر من الشرطة أو المحاكم لا من الضحية.",
    "AI-assisted malware" => "البرمجيات الخبيثة بمساعدة الذكاء الاصطناعي برامج ضارة كُتبت أو عُدّلت أو شُغّلت بمساعدة نماذج ذكاء اصطناعي. يشمل ذلك الشيفرات التي تولّدها المساعدات، والبرمجيات التي تستدعي نموذجًا أثناء التشغيل لتقرير خطوتها التالية، والأدوات الإجرامية المبنية على نماذج اللغة. يقلّل الذكاء الاصطناعي المهارة والوقت اللازمين لإنتاج شيفرة هجوم فعّالة.",
    "AI supply chain" => "تُخلّ حادثة سلسلة توريد الذكاء الاصطناعي بمكوّن تعتمد عليه أنظمة الذكاء الاصطناعي: ملف نموذج، أو مجموعة بيانات، أو أداة تطوير، أو إضافة، أو سجل حزم، أو منصة استضافة. مكوّن خبيث أو مُعرَّض واحد قد يصل إلى كل مشروع يثبّته. تشمل الحالات حزمًا مسمومة ونماذج بأبواب خلفية ومساعدات برمجة مُختَرقة.",
    "Model & data leak" => "يكشف تسريب النماذج والبيانات معلومات يحتفظ بها نظام ذكاء اصطناعي: محادثات المستخدمين، أو مفاتيح API، أو بيانات التدريب، أو أوزان النموذج، أو الإعدادات الداخلية. تتراوح الأسباب بين قواعد بيانات ومخازن سيئة الإعداد وثغرات في التطبيق المحيط بالنموذج. ويُقاس الضرر بما كُشف ولكم من الوقت.",
    "LLMjacking" => "اختطاف نماذج اللغة هو سرقة الوصول إلى نماذج ذكاء اصطناعي مدفوعة، عادةً عبر بيانات اعتماد سحابية أو مفاتيح API مسروقة. يشغّل المهاجمون أعباءهم الخاصة أو يبيعون الوصول بينما تتلقى الضحية الفاتورة. وهو المعادل في الذكاء الاصطناعي لاختطاف التعدين.",
    "Agent hijack" => "يستولي اختطاف الوكلاء على وكيل ذكاء اصطناعي، أي نموذج مزوَّد بأدوات مثل متصفح أو سطر أوامر أو بريد إلكتروني أو أنظمة دفع، ويجعله يتصرّف ضد مالكه. نقطة الدخول غالبًا حقن أوامر أو أداة مُختَرقة، وتصبح صلاحيات الوكيل صلاحيات المهاجم. تشمل الأضرار ملفات محذوفة وبيانات مسرّبة وإجراءات غير مصرّح بها تُنفَّذ آليًا.",
    "AI phishing" => "يستخدم التصيّد بالذكاء الاصطناعي نماذج اللغة لكتابة رسائل احتيالية وترجمتها وتخصيصها على نطاق واسع، أو لبناء مواقع وروبوتات محادثة مزيفة تجمع بيانات الاعتماد. النص سليم ومُوجَّه، فتختفي علامات التحذير التقليدية مثل الأخطاء الإملائية. تشمل الحالات حملات ضد مسؤولين وشركات ومستهلكين.",
    "State actor AI ops" => "عمليات الدول بالذكاء الاصطناعي هي استخدام مجموعات مرتبطة بحكومات للذكاء الاصطناعي في التجسس أو حملات التأثير أو الهجمات السيبرانية. تأتي التقارير غالبًا من مزوّدي الذكاء الاصطناعي الذين يكشفون الحسابات المعنية ويعطّلونها، ومن الجهات الحكومية. ويُسجَّل الإسناد كما ذكره المصدر مع مستوى ثقته."
  },
  "zh" => {
    "Prompt injection" => "提示注入是一种攻击：AI 模型读取的文本（如网页、文档或电子邮件）中夹带指令，模型将其当作用户或运营者的指令执行。它可使助手泄露数据、执行不该执行的操作或无视安全规则。这是针对大语言模型系统最常见的一类攻击。",
    "Deepfake fraud" => "深度伪造欺诈利用 AI 生成的语音、视频或图像冒充真人（通常是高管、亲属或公众人物）以欺骗受害者。典型案例包括授权付款的虚假视频通话，以及用于诈骗电话的克隆语音。损失往往由警方或法院而非受害者公布。",
    "AI-assisted malware" => "AI 辅助恶意软件是在 AI 模型帮助下编写、改造或操控的恶意软件。它包括由助手生成的代码、在运行时调用模型决定下一步的恶意软件，以及基于语言模型构建的犯罪工具包。AI 降低了制作可用攻击代码所需的技能和时间。",
    "AI supply chain" => "AI 供应链事件破坏的是 AI 系统所依赖的组件：模型文件、数据集、开发工具、扩展、软件包仓库或托管平台。一个恶意或存在漏洞的组件可以波及所有安装它的项目。案例包括投毒的软件包、植入后门的模型和被攻陷的编程助手。",
    "Model & data leak" => "模型与数据泄露指 AI 系统所持有的信息被暴露：用户对话、API 密钥、训练数据、模型权重或内部配置。原因从配置错误的数据库和存储，到模型外围应用的缺陷。危害取决于暴露了什么以及暴露了多久。",
    "LLMjacking" => "LLM 劫持是窃取付费 AI 模型的访问权限，通常通过被盗的云凭据或 API 密钥。攻击者运行自己的工作负载或转售访问权限，账单却由受害者承担。它是 AI 领域的“加密货币劫持”。",
    "Agent hijack" => "代理劫持是控制一个 AI 代理（即配有浏览器、命令行、电子邮件或支付系统等工具的模型），使其对抗其所有者。入口通常是提示注入或被攻陷的工具，代理的权限随之变成攻击者的权限。损害包括文件被删除、数据泄露以及自动执行的未授权操作。",
    "AI phishing" => "AI 钓鱼利用语言模型大规模撰写、翻译和个性化欺诈信息，或搭建窃取凭据的虚假网站和聊天机器人。文本流畅且有针对性，拼写错误等传统警示信号随之消失。案例包括针对官员、企业和消费者的活动。",
    "State actor AI ops" => "国家行为者 AI 行动指与政府相关的团体将 AI 用于间谍活动、影响力行动或网络攻击。报告主要来自检测并封禁相关账户的 AI 提供商，以及政府机构。归因按来源的表述及其置信度如实记录。"
  }
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

def plural(n)
  n == 1 ? "1 case" : "#{n} cases"
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
    <style>#{CSS}#{SUBSCRIBE_CSS}</style>
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
  parts << %(<span><a href="#{pre(lang)}/about/">#{h(x(lang, :about))}</a> · <a href="#{pre(lang)}/cases/glossary/">#{h(x(lang, :glossary))}</a> · <a href="#{pre(lang)}/cases/">#{h(x(lang, :all_cases))}</a></span>)
  parts << %(<span><a href="/data/incidents.en.json">#{h(x(lang, :data))}</a> · <a href="#{pre(lang)}/cases/feed.xml">#{h(x(lang, :cases_feed))}</a> · <a href="/feed.xml">#{h(x(lang, :wire_feed))}</a> · <a href="/sitemap.xml">Sitemap</a></span>)
  %(<footer>#{parts.join}</footer>)
end

def para(label, v, lang)
  return "" unless present(v)
  label ? %(<p><span class="lbl">#{h(label)}: </span>#{h(v)}</p>) : %(<p>#{h(v)}</p>)
end

# Email sign-up (MailerLite embedded form "aithreat alerts", double opt-in). Plain HTML
# form: MailerLite shows its "check your inbox" page in a new tab. Same form as the
# homepage card in site/index.html.
SUBSCRIBE_URL = "https://assets.mailerlite.com/jsonp/2715122/forms/201398923747657688/subscribe"
SUBSCRIBE_CSS = ".sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}.sub{background:var(--surface);border:1px solid var(--line2);border-radius:12px;padding:16px 18px;margin:26px 0 0;display:grid;gap:8px}.sub .k{font:600 11px var(--f-mono);text-transform:uppercase;letter-spacing:.06em;color:var(--accent)}html[lang=\"ar\"] .sub .k,html[lang=\"zh\"] .sub .k{font-family:var(--f-body);text-transform:none;letter-spacing:0}.sub h2{margin:0;font-size:18px}.sub form{display:flex;flex-wrap:wrap;gap:8px}.sub input[type=email]{flex:1 1 220px;min-height:40px;border:1px solid var(--line2);border-radius:8px;background:var(--surface2);color:var(--ink);padding:0 12px;font:15px var(--f-body)}.sub button{min-height:40px;padding:0 16px;border:0;border-radius:8px;background:var(--accent);color:var(--accent-ink);font:600 14px var(--f-body);cursor:pointer}.sub small{color:var(--muted)}"
def subscribe_box(lang)
  <<~HTML
    <aside class="sub" aria-labelledby="sub-h"><div class="k">#{h(t(lang, 'get_alerts'))}</div><h2 id="sub-h">#{h(t(lang, 'alerts_h'))}</h2>
    <form method="post" action="#{SUBSCRIBE_URL}" target="_blank"><label class="sr" for="sub-email">Email</label><input type="email" name="fields[email]" id="sub-email" required placeholder="#{h(t(lang, 'alerts_ph'))}" autocomplete="email"><input type="hidden" name="ml-submit" value="1"><input type="hidden" name="anticsrf" value="true"><button type="submit">#{h(t(lang, 'subscribe'))}</button></form>
    <small>#{h(t(lang, 'alerts_note'))} <a href="#{pre(lang)}/cases/feed.xml">RSS</a></small></aside>
  HTML
end

def shell(lang, current, headhtml, body, alternates)
  html = headhtml + %(<body><div class="wrap">#{bar(lang, current)}<main>#{body}#{subscribe_box(lang)}#{footer(lang)}</main></div></body></html>)
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
def list_page(items_en, lang, kind:, key: nil, all_cats: [], all_countries: [], all_companies: [])
  path = case kind
         when :index then "#{pre(lang)}/cases/"
         when :cat then "#{pre(lang)}/cases/category/#{slug(key)}/"
         when :country then "#{pre(lang)}/cases/country/#{slug(key)}/"
         when :company then "#{pre(lang)}/cases/company/#{slug(key)}/"
         end
  url = BASE + path
  alternates = Hash[LANGS.map { |l| [l, BASE + path.sub(%r{\A#{Regexp.escape(pre(lang))}/}, "#{pre(l)}/")] }]
  title = case kind
          when :index then x(lang, :all_cases)
          when :cat then x(lang, :cat_h, cat: tt(lang, "cats", key))
          when :country then x(lang, :country_h, place: place_name(lang, key))
          when :company then x(lang, :company_h, company: key)
          end
  n = items_en.size
  intro = if kind == :company then x(lang, (n == 1 ? :company_intro_1 : :company_intro), n: n, company: key) else x(lang, :index_intro, n: n) end
  jsonld = [{ "@context" => "https://schema.org", "@type" => "CollectionPage", "name" => "#{title} · AI Threat Watch", "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
              "license" => "https://creativecommons.org/licenses/by/4.0/", "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
              "mainEntity" => { "@type" => "ItemList", "numberOfItems" => n, "itemListElement" => items_en.first(100).each_with_index.map { |i, k| { "@type" => "ListItem", "position" => k + 1, "url" => case_url(lang, i["id"]), "name" => (localized(i, lang) || i)["title"] } } } }]
  jsonld[0]["about"] = { "@type" => "Organization", "name" => key } if kind == :company
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: intro, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")

  chips_cat = all_cats.map { |c| %(<a href="#{pre(lang)}/cases/category/#{slug(c)}/"#{kind == :cat && c == key ? ' aria-current="page"' : ''}>#{h(tt(lang, 'cats', c))}</a>) }.join
  chips_cc = all_countries.map { |c| %(<a href="#{pre(lang)}/cases/country/#{slug(c)}/"#{kind == :country && c == key ? ' aria-current="page"' : ''}>#{h(place_name(lang, c))}</a>) }.join
  chips_co = all_companies.map { |c| %(<a href="#{pre(lang)}/cases/company/#{slug(c)}/"#{kind == :company && c == key ? ' aria-current="page"' : ''}>#{h(c)}</a>) }.join
  rows = items_en.map do |i_en|
    i = localized(i_en, lang) || i_en
    %(<li><time datetime="#{h(i['date'])}">#{h(fmt_date(i['date'], lang))}</time><div><a href="#{h(case_url(lang, i['id']))}">#{h(i['title'])}</a><div class="meta"><span class="pill sev" data-sev="#{i['severity']}">#{h(tt(lang, 'sev', i['severity']))}</span> · #{h(tt(lang, 'cats', i['category']))} · #{h(i['target'])} · #{h(place_name(lang, i['country']))}</div></div></li>)
  end.join
  crumbs = kind == :index ? "" : %(<nav class="crumbs" aria-label="Breadcrumb"><a href="/#{lang == 'en' ? '' : '?lang=' + lang}">AI Threat Watch</a> › <a href="#{pre(lang)}/cases/">#{h(x(lang, :all_cases))}</a></nav>)
  body = <<~HTML
    #{crumbs}
    <h1 style="margin-top:#{kind == :index ? '22px' : '0'}">#{h(title)}</h1>
    <p class="lede">#{h(intro)}</p>
    <h3 class="sub">#{h(x(lang, :by_cat))} · <a href="#{pre(lang)}/cases/glossary/">#{h(x(lang, :glossary))}</a></h3><div class="chips"><a href="#{pre(lang)}/cases/"#{kind == :index ? ' aria-current="page"' : ''}>#{h(t(lang, 'ver_all'))}</a>#{chips_cat}</div>
    <h3 class="sub">#{h(x(lang, :by_country))}</h3><div class="chips">#{chips_cc}</div>
    <h3 class="sub">#{h(x(lang, :by_company))}</h3><div class="chips">#{chips_co}</div>
    <ul class="cases">#{rows}</ul>
  HTML
  shell(lang, "cases", headhtml, body, alternates)
end

def crumbs_html(lang, trail)
  q = lang == "en" ? "" : "?lang=#{lang}"
  items = [%(<a href="/#{q}">AI Threat Watch</a>)] + trail.map { |label, href| href ? %(<a href="#{h(href)}">#{h(label)}</a>) : h(label) }
  %(<nav class="crumbs" aria-label="Breadcrumb">#{items.join(' › ')}</nav>)
end

def crumbs_ld(lang, trail)
  items = [["AI Threat Watch", "#{BASE}/"]] + trail
  { "@context" => "https://schema.org", "@type" => "BreadcrumbList", "itemListElement" => items.each_with_index.map { |(name, href), k| { "@type" => "ListItem", "position" => k + 1, "name" => name, "item" => href } } }
end

# ---------- glossary ----------
def glossary_page(lang, cats, counts)
  path = "#{pre(lang)}/cases/glossary/"
  url = BASE + path
  alternates = Hash[LANGS.map { |l| [l, "#{BASE}#{pre(l)}/cases/glossary/"] }]
  title = x(lang, :glossary_h)
  intro = x(lang, :glossary_intro)
  defs = GLOSSARY[lang] || GLOSSARY["en"]
  terms = cats.map do |c|
    name = tt(lang, "cats", c)
    { "@type" => "DefinedTerm", "@id" => "#{url}##{slug(c)}", "name" => name, "description" => defs[c] || GLOSSARY["en"][c], "url" => "#{url}##{slug(c)}", "inDefinedTermSet" => url }
  end
  jsonld = [
    { "@context" => "https://schema.org", "@type" => "DefinedTermSet", "@id" => url, "name" => title, "description" => intro, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" }, "hasDefinedTerm" => terms },
    crumbs_ld(lang, [[x(lang, :all_cases), "#{BASE}#{pre(lang)}/cases/"], [x(lang, :glossary), url]])
  ]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: intro, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  toc = cats.map { |c| %(<a href="##{slug(c)}">#{h(tt(lang, 'cats', c))}</a>) }.join
  entries = cats.map do |c|
    hub = "#{pre(lang)}/cases/category/#{slug(c)}/"
    n = counts[c] || 0
    %(<section class="sec" id="#{slug(c)}"><h2>#{h(tt(lang, 'cats', c))}</h2><p>#{h(defs[c] || GLOSSARY['en'][c])}</p><p><a href="#{hub}">#{h(x(lang, :glossary_see))}: #{h(x(lang, :glossary_cases, n: n))}</a></p></section>)
  end.join
  body = <<~HTML
    #{crumbs_html(lang, [[x(lang, :all_cases), "#{pre(lang)}/cases/"], [x(lang, :glossary), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(intro)}</p>
    <div class="chips">#{toc}</div>
    #{entries}
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "cases", headhtml, body, alternates)
end

# ---------- about / method ----------
HF_URL = "https://huggingface.co/datasets/karlabouzeid/ai-security-incidents"
MIRRORS_H = {"en"=>"Downloads and mirrors", "fr"=>"Téléchargements et miroirs", "es"=>"Descargas y réplicas", "ar"=>"التنزيلات والنسخ", "zh"=>"下载与镜像"}.freeze

def about_page(lang, newest_en)
  path = "#{pre(lang)}/about/"
  url = BASE + path
  alternates = Hash[LANGS.map { |l| [l, "#{BASE}#{pre(l)}/about/"] }]
  title = x(lang, :about_h)
  intro = x(lang, :about_intro)
  jsonld = [
    { "@context" => "https://schema.org", "@type" => "AboutPage", "@id" => url, "name" => title, "description" => intro, "url" => url, "inLanguage" => lang, "isAccessibleForFree" => true,
      "license" => "https://creativecommons.org/licenses/by/4.0/", "about" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" },
      "publisher" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/" }, "mainEntity" => { "@type" => "Organization", "name" => "AI Threat Watch", "url" => "#{BASE}/", "sameAs" => [REPO] } },
    crumbs_ld(lang, [[x(lang, :about), url]])
  ]
  headhtml = head(lang: lang, title: "#{title} · AI Threat Watch", desc: intro, url: url, alternates: alternates, jsonld: jsonld, feed: "#{pre(lang)}/cases/feed.xml")
  sev_rows = %w[critical high medium low].map { |s| %(<li><span class="pill sev" data-sev="#{s}">#{h(tt(lang, 'sev', s))}</span> <span>#{h(x(lang, "sev_#{s}".to_sym))}</span></li>) }.join
  ex = localized(newest_en, lang) || newest_en
  ex_url = case_url(lang, ex["id"])
  example = "#{ex['title']}. AI Threat Watch, #{t(lang, 'case').downcase} #{ex['id']}, #{fmt_date(ex['date'], lang)}. #{ex_url}"
  body = <<~HTML
    #{crumbs_html(lang, [[x(lang, :about), nil]])}
    <h1>#{h(title)}</h1>
    <p class="lede">#{h(intro)}</p>
    <section class="sec"><h2>#{h(x(lang, :about_wire_h))}</h2><p>#{h(x(lang, :about_wire_p1))}</p><p>#{h(x(lang, :about_wire_p2))}</p><p>#{h(x(lang, :about_langs))}</p></section>
    <section class="sec"><h2>#{h(t(lang, 'dt_method_h'))}</h2><p>#{h(t(lang, 'dt_method_p'))}</p></section>
    <div class="two">
      <section class="sec"><h2>#{h(t(lang, 'dt_sev_h'))}</h2><ul class="srcs">#{sev_rows}</ul></section>
      <section class="sec"><h2>#{h(t(lang, 'ww'))}</h2><p>#{h(t(lang, 'ww_hint'))}</p><p>#{h(t(lang, 'ww_sub'))}</p></section>
    </div>
    <section class="sec" id="licence"><h2>#{h(x(lang, :about_lic_h))}</h2><p>#{h(x(lang, :about_lic_p))}</p><p><a href="https://creativecommons.org/licenses/by/4.0/" rel="license noopener" target="_blank">CC BY 4.0</a></p><p><span class="lbl">#{h(MIRRORS_H[lang] || MIRRORS_H['en'])}: </span><a href="/data/incidents.en.json">JSON</a> · <a href="#{HF_URL}" rel="noopener" target="_blank">Hugging Face</a> · <a href="#{REPO}" rel="noopener" target="_blank">GitHub</a></p><p>#{h(t(lang, 'dt_cite_p'))}</p><pre class="cite">#{h(x(lang, :cite_fmt, case: t(lang, 'case').downcase))}</pre><p class="lbl">#{h(x(lang, :cite_example))}:</p><pre class="cite">#{h(example)}</pre></section>
    <section class="sec" id="corrections"><h2>#{h(x(lang, :about_corr_h))}</h2><p>#{h(x(lang, :about_corr_p))}</p><p><a href="#{CHANGELOG_URL}" rel="noopener" target="_blank">#{h(x(lang, :changelog))}</a></p></section>
    <section class="sec" id="contact"><h2>#{h(x(lang, :about_contact_h))}</h2><p>#{h(t(lang, 'dt_contact'))}</p><p>#{h(x(lang, :about_contact_p))} <a href="#{ISSUES_URL}" rel="noopener" target="_blank">#{h(x(lang, :github_issues))}</a></p></section>
    <p class="langs">#{h(t(lang, 'lang'))}: #{lang_links(lang, alternates)}</p>
  HTML
  shell(lang, "about", headhtml, body, alternates)
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
glossary_cats = (UI["en"]["cats"] || {}).keys + (cats - (UI["en"]["cats"] || {}).keys)
cat_counts = Hash[glossary_cats.map { |c| [c, incidents.count { |i| i["category"] == c }] }]
countries = incidents.map { |i| i["country"] || "GL" }.uniq.sort_by { |c| [c == "GL" ? 1 : 0, c] }
companies = incidents.map { |i| i["target"] }.select { |v| present(v) }.map(&:strip).uniq.sort_by { |c| [slug(c), c] }
abort "build_pages: two targets produce the same company slug" if companies.map { |c| slug(c) }.uniq.size != companies.size

LANGS.each { |l| FileUtils.rm_rf(File.join(SITE, pre(l).sub("/", ""), "cases")); FileUtils.rm_rf(File.join(SITE, pre(l).sub("/", ""), "about")) }
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
  lists = { all_cats: cats, all_countries: countries, all_companies: companies }
  write.("#{pre(lang)}/cases/index.html", list_page(avail, lang, kind: :index, **lists))
  cats.each { |c| write.("#{pre(lang)}/cases/category/#{slug(c)}/index.html", list_page(avail.select { |i| i['category'] == c }, lang, kind: :cat, key: c, **lists)) }
  countries.each { |c| write.("#{pre(lang)}/cases/country/#{slug(c)}/index.html", list_page(avail.select { |i| (i['country'] || 'GL') == c }, lang, kind: :country, key: c, **lists)) }
  companies.each { |c| write.("#{pre(lang)}/cases/company/#{slug(c)}/index.html", list_page(avail.select { |i| i['target'].to_s.strip == c }, lang, kind: :company, key: c, **lists)) }
  write.("#{pre(lang)}/cases/glossary/index.html", glossary_page(lang, glossary_cats, cat_counts))
  write.("#{pre(lang)}/about/index.html", about_page(lang, incidents.first))
  write.("#{pre(lang)}/cases/feed.xml", feed(avail, lang))
end

# Redirects for case files that were merged into another (config/redirects.json: old id => kept id).
# The old URLs are still linked from feeds, search results and other sites, so each gets a small
# page that sends readers and crawlers to the kept file. Rewritten on every run, not in the sitemap.
redirects_path = File.join(ROOT, "config", "redirects.json")
redirects = File.exist?(redirects_path) ? JSON.parse(File.read(redirects_path, encoding: "UTF-8")) : {}
ids = incidents.map { |i| i["id"] }
redirects.each do |old_id, new_id|
  abort "build_pages: redirect source #{old_id} is still a case file" if ids.include?(old_id)
  abort "build_pages: redirect target #{new_id} is not a case file" unless ids.include?(new_id)
  LANGS.each do |lang|
    to = case_url(lang, new_id)
    write.("#{pre(lang)}/cases/#{old_id}/index.html", <<~HTML)
      <!doctype html>
      <html lang="#{lang}"#{RTL.include?(lang) ? ' dir="rtl"' : ''}>
      <head>
      <meta charset="utf-8">
      <title>AI Threat Watch: #{h(new_id)}</title>
      <meta name="robots" content="noindex">
      <meta http-equiv="refresh" content="0; url=#{h(to)}">
      <link rel="canonical" href="#{h(to)}">
      </head>
      <body>
      <p>This case file was merged into <a href="#{h(to)}">#{h(to)}</a>.</p>
      </body>
      </html>
    HTML
  end
end

# sitemap: group alternates per logical page
incidents.each { |i| add_url.(case_url("en", i["id"]), Hash[langs_for(i).map { |l| [l, case_url(l, i["id"])] }]) }
%w[fr es ar zh].each { |l| incidents.select { |i| langs_for(i).include?(l) }.each { |i| add_url.(case_url(l, i["id"]), Hash[langs_for(i).map { |m| [m, case_url(m, i["id"])] }]) } }
list_paths = ["/cases/", "/cases/glossary/", "/about/"] + cats.map { |c| "/cases/category/#{slug(c)}/" } + countries.map { |c| "/cases/country/#{slug(c)}/" } + companies.map { |c| "/cases/company/#{slug(c)}/" }
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
llm << "- [About and method](#{BASE}/about/): inclusion rule, severity scale, verified case files versus the machine-triaged wire, CC BY 4.0 licence and citation format, corrections policy (public change log, no silent edits), contact"
llm << "- [Glossary of incident types](#{BASE}/cases/glossary/): plain-language definitions of the nine categories, each linked to its cases"
llm << "- Company hubs: #{BASE}/cases/company/<slug>/ lists the cases in which one company or product was the target (see the list below)"
llm << ""
llm << "## Open data"
llm << "- [incidents.en.json](#{BASE}/data/incidents.en.json): the full verified dataset (fields: id, date, title, category, direction, severity, country, region, target, loss_usd, summary, actor, actor_type, attribution, motive, vector, root_cause, timeline, impact, response, status, cve, sources)"
llm << "- [Verified case files RSS](#{BASE}/cases/feed.xml)"
llm << "- [Live wire RSS](#{BASE}/feed.xml)"
llm << "- [Sitemap](#{BASE}/sitemap.xml)"
llm << ""
llm << "## Case files by type"
cats.each { |c| llm << "- [#{c}](#{BASE}/cases/category/#{slug(c)}/): #{plural(incidents.count { |i| i['category'] == c })}" }
llm << ""
llm << "## Case files by company"
companies.each { |c| llm << "- [#{c}](#{BASE}/cases/company/#{slug(c)}/): #{plural(incidents.count { |i| i['target'].to_s.strip == c })}" }
llm << ""
llm << "## Verified case files"
incidents.each { |i| llm << "- [#{i['title']}](#{case_url('en', i['id'])}): #{i['date']}, #{i['severity']}, #{i['category']}, #{place_name('en', i['country'])}. #{i['summary']}" }
llm << ""
llm << "## Citing"
llm << "Cite a case as: <title>. AI Threat Watch, case <id>, <date>. <permanent link>. Licence: CC BY 4.0 (reuse with a link)."
File.write(File.join(SITE, "llms.txt"), llm.join("\n") + "\n")

puts "build_pages: #{written} pages, #{sitemap.size} sitemap entries, #{incidents.size} cases, languages: #{LANGS.map { |l| "#{l}=#{incidents.count { |i| langs_for(i).include?(l) }}" }.join(' ')}"
