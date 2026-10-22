# frozen_string_literal: true
# The site-wide reporting window: every page shows the last 12 months by default and says so;
# older case files stay online as an archive. Labels in the six site languages, used by the
# static pages (merged into EXTRA by build_pages.rb) and the homepage (merged into HOME by
# home_strings.rb, then copied into site/index.html by sync_home_strings.rb).
# Research vs reality is the one exception: it compares warnings with all case files ever filed.

WINDOW_DAYS = 365

WINDOW = {
  "en" => {
    w12: "Last 12 months", w12_since: "Last 12 months · since {date}", all_time_n: "All time: {n}",
    win_all_note: "All case files since 2022", older_h: "Older than 12 months (archive)",
    archive_badge: "Archive · reported more than 12 months ago",
    p_window: "Figures cover the last 12 months ({from} to {to}) unless a chart says otherwise; all-time totals are shown underneath.",
    research_all_time: "All time: warnings are compared with every case file since 2022, not only the last 12 months.",
    q8: "Last 8 quarters"
  },
  "fr" => {
    w12: "12 derniers mois", w12_since: "12 derniers mois · depuis le {date}", all_time_n: "Depuis le début : {n}",
    win_all_note: "Tous les dossiers depuis 2022", older_h: "Plus de 12 mois (archives)",
    archive_badge: "Archives · signalé il y a plus de 12 mois",
    p_window: "Les chiffres couvrent les 12 derniers mois (du {from} au {to}) sauf mention contraire sur un graphique ; les totaux depuis le début figurent en dessous.",
    research_all_time: "Depuis le début : les avertissements sont comparés à tous les dossiers depuis 2022, pas seulement aux 12 derniers mois.",
    q8: "8 derniers trimestres"
  },
  "es" => {
    w12: "Últimos 12 meses", w12_since: "Últimos 12 meses · desde el {date}", all_time_n: "Desde el inicio: {n}",
    win_all_note: "Todos los expedientes desde 2022", older_h: "Más de 12 meses (archivo)",
    archive_badge: "Archivo · reportado hace más de 12 meses",
    p_window: "Las cifras cubren los últimos 12 meses (del {from} al {to}) salvo que un gráfico indique lo contrario; los totales desde el inicio aparecen debajo.",
    research_all_time: "Desde el inicio: las advertencias se comparan con todos los expedientes desde 2022, no solo con los últimos 12 meses.",
    q8: "Últimos 8 trimestres"
  },
  "ar" => {
    w12: "آخر 12 شهرًا", w12_since: "آخر 12 شهرًا · منذ {date}", all_time_n: "منذ البداية: {n}",
    win_all_note: "كل الملفات منذ 2022", older_h: "أقدم من 12 شهرًا (الأرشيف)",
    archive_badge: "أرشيف · أُبلغ عنه قبل أكثر من 12 شهرًا",
    p_window: "تغطي الأرقام آخر 12 شهرًا (من {from} إلى {to}) ما لم يذكر الرسم غير ذلك؛ وتظهر المجاميع منذ البداية أسفلها.",
    research_all_time: "منذ البداية: تُقارن التحذيرات بكل الملفات منذ 2022، لا بآخر 12 شهرًا فقط.",
    q8: "آخر 8 أرباع"
  },
  "zh" => {
    w12: "最近 12 个月", w12_since: "最近 12 个月 · 自 {date} 起", all_time_n: "全部时间：{n}",
    win_all_note: "自 2022 年以来的全部档案", older_h: "超过 12 个月（存档）",
    archive_badge: "存档 · 报道于 12 个月以前",
    p_window: "除图表另有说明外，数据涵盖最近 12 个月（{from} 至 {to}）；全部时间的总数列于下方。",
    research_all_time: "全部时间：警告与 2022 年以来的全部案例档案对照，而不仅是最近 12 个月。",
    q8: "最近 8 个季度"
  },
  "ru" => {
    w12: "Последние 12 месяцев", w12_since: "Последние 12 месяцев · с {date}", all_time_n: "За всё время: {n}",
    win_all_note: "Все досье с 2022 года", older_h: "Старше 12 месяцев (архив)",
    archive_badge: "Архив · опубликовано более 12 месяцев назад",
    p_window: "Данные охватывают последние 12 месяцев (с {from} по {to}), если на графике не указано иное; итоги за всё время приведены ниже.",
    research_all_time: "За всё время: предупреждения сопоставляются со всеми досье с 2022 года, а не только за последние 12 месяцев.",
    q8: "Последние 8 кварталов"
  }
}.freeze
