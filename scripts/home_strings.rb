# frozen_string_literal: true
# Labels for the homepage sections (intro, latest cases, news, map, trends, research, alerts), in the six
# site languages. scripts/sync_home_strings.rb copies these, plus the i_* and u_* texts from info_strings.rb,
# into the UI table of site/index.html.

HOME = {
  "en" => {
    hm_h1: "Every verified AI security incident, with its sources",
    hm_lede: "An open registry of attacks on AI systems and attacks carried out with AI, updated every 30 minutes and checked against primary sources before it is published.",
    hm_countries: "Countries",
    latest_h: "Latest verified cases", latest_sub: "The five newest verified cases, by the date they were made public.", read_case: "Read the case file →",
    news_h: "News wire", news_sub: "The latest stories from {n} sources, before an editor has checked them.", news_all: "Open the wire →",
    map_h: "Map", map_sub: "Every case by location. Pin colour shows the worst severity, size the number of cases.",
    trends_h: "Trends", trends_sub: "How the registry is changing.", trends_all: "All trends →", month_h: "Cases per month", types_h: "Most common types",
    rsch_h: "Research vs reality", rsch_sub: "What AI-risk researchers warned about, and what has happened since.", rsch_all: "All {n} warnings →", rsch_card: "Three warnings and where they stand", rsch_n: "{n} matching case files",
    alerts_h2: "Get alerts", alerts_sub: "Every verified case, as soon as it is published.", tg_p: "An instant post for every verified case.", bs_p: "Follow @aithreat.io for every verified case.", follow: "Follow", rss_h: "RSS and data", rss_p: "Feeds by severity, type and country, and the full dataset as JSON.", all_feeds: "All feeds"
  },
  "fr" => {
    hm_h1: "Chaque incident de sécurité de l'IA vérifié, avec ses sources",
    hm_lede: "Un registre ouvert des attaques contre des systèmes d'IA et des attaques menées avec l'IA, mis à jour toutes les 30 minutes et vérifié à partir des sources primaires avant publication.",
    hm_countries: "Pays",
    latest_h: "Derniers dossiers vérifiés", latest_sub: "Les cinq dossiers vérifiés les plus récents, selon leur date de publication.", read_case: "Lire le dossier →",
    news_h: "Fil d'actualité", news_sub: "Les derniers articles de {n} sources, avant vérification par un éditeur.", news_all: "Ouvrir le fil →",
    map_h: "Carte", map_sub: "Tous les dossiers par lieu. La couleur indique la gravité la plus élevée, la taille le nombre de dossiers.",
    trends_h: "Tendances", trends_sub: "Comment évolue le registre.", trends_all: "Toutes les tendances →", month_h: "Dossiers par mois", types_h: "Types les plus fréquents",
    rsch_h: "Recherche et réalité", rsch_sub: "Ce contre quoi les chercheurs en risques de l'IA ont mis en garde, et ce qui s'est passé depuis.", rsch_all: "Les {n} avertissements →", rsch_card: "Trois avertissements et où ils en sont", rsch_n: "{n} dossiers correspondants",
    alerts_h2: "Recevoir les alertes", alerts_sub: "Chaque dossier vérifié, dès sa publication.", tg_p: "Une publication immédiate pour chaque dossier vérifié.", bs_p: "Suivez @aithreat.io pour chaque dossier vérifié.", follow: "Suivre", rss_h: "RSS et données", rss_p: "Flux par gravité, type et pays, et le jeu de données complet en JSON.", all_feeds: "Tous les flux"
  },
  "es" => {
    hm_h1: "Cada incidente de seguridad de la IA verificado, con sus fuentes",
    hm_lede: "Un registro abierto de ataques contra sistemas de IA y ataques realizados con IA, actualizado cada 30 minutos y contrastado con fuentes primarias antes de publicarse.",
    hm_countries: "Países",
    latest_h: "Últimos casos verificados", latest_sub: "Los cinco casos verificados más recientes, según la fecha en que se hicieron públicos.", read_case: "Leer el expediente →",
    news_h: "Hilo de noticias", news_sub: "Las últimas noticias de {n} fuentes, antes de que las revise un editor.", news_all: "Abrir el hilo →",
    map_h: "Mapa", map_sub: "Todos los casos por lugar. El color indica la gravedad máxima y el tamaño, el número de casos.",
    trends_h: "Tendencias", trends_sub: "Cómo está cambiando el registro.", trends_all: "Todas las tendencias →", month_h: "Casos por mes", types_h: "Tipos más comunes",
    rsch_h: "Investigación y realidad", rsch_sub: "Sobre qué advirtieron los investigadores de riesgos de la IA y qué ha pasado desde entonces.", rsch_all: "Las {n} advertencias →", rsch_card: "Tres advertencias y cómo están", rsch_n: "{n} expedientes coincidentes",
    alerts_h2: "Recibir alertas", alerts_sub: "Cada caso verificado, en cuanto se publica.", tg_p: "Una publicación inmediata por cada caso verificado.", bs_p: "Siga a @aithreat.io para cada caso verificado.", follow: "Seguir", rss_h: "RSS y datos", rss_p: "Feeds por gravedad, tipo y país, y el conjunto de datos completo en JSON.", all_feeds: "Todos los feeds"
  },
  "ar" => {
    hm_h1: "كل حادث أمني موثّق متعلق بالذكاء الاصطناعي، مع مصادره",
    hm_lede: "سجل مفتوح للهجمات على أنظمة الذكاء الاصطناعي والهجمات المنفّذة به، يُحدَّث كل 30 دقيقة ويُدقَّق مقابل المصادر الأولية قبل نشره.",
    hm_countries: "الدول",
    latest_h: "أحدث الحالات الموثّقة", latest_sub: "أحدث خمس حالات موثّقة، حسب تاريخ الإعلان عنها.", read_case: "اقرأ ملف الحالة ←",
    news_h: "شريط الأخبار", news_sub: "آخر الأخبار من {n} مصدراً، قبل أن يراجعها محرّر.", news_all: "افتح الشريط ←",
    map_h: "الخريطة", map_sub: "كل الحالات حسب المكان. لون الدبوس يبيّن أعلى درجة خطورة، وحجمه عدد الحالات.",
    trends_h: "الاتجاهات", trends_sub: "كيف يتغيّر السجل.", trends_all: "كل الاتجاهات ←", month_h: "الحالات شهرياً", types_h: "الأنواع الأكثر شيوعاً",
    rsch_h: "الأبحاث مقابل الواقع", rsch_sub: "ما حذّر منه باحثو مخاطر الذكاء الاصطناعي، وما حدث منذ ذلك الحين.", rsch_all: "التحذيرات الـ{n} كلها ←", rsch_card: "ثلاثة تحذيرات وأين وصلت", rsch_n: "{n} ملفات حالات مطابقة",
    alerts_h2: "تلقَّ التنبيهات", alerts_sub: "كل حالة موثّقة فور نشرها.", tg_p: "منشور فوري لكل حالة موثّقة.", bs_p: "تابِع @aithreat.io لكل حالة موثّقة.", follow: "تابِع", rss_h: "RSS والبيانات", rss_p: "خلاصات حسب الخطورة والنوع والدولة، ومجموعة البيانات كاملة بصيغة JSON.", all_feeds: "كل الخلاصات"
  },
  "zh" => {
    hm_h1: "每一起经核实的 AI 安全事件，附来源",
    hm_lede: "一个开放的登记册，收录针对 AI 系统的攻击和利用 AI 实施的攻击，每 30 分钟更新一次，发布前均与一手来源核对。",
    hm_countries: "国家",
    latest_h: "最新核实案例", latest_sub: "最新的五个已核实案例，按公开日期排列。", read_case: "阅读案例档案 →",
    news_h: "新闻流", news_sub: "来自 {n} 个来源的最新报道，尚未经编辑核实。", news_all: "打开新闻流 →",
    map_h: "地图", map_sub: "按地点显示所有案例。标记颜色表示最高严重程度，大小表示案例数量。",
    trends_h: "趋势", trends_sub: "登记册的变化。", trends_all: "全部趋势 →", month_h: "每月案例数", types_h: "最常见类型",
    rsch_h: "研究与现实", rsch_sub: "AI 风险研究人员曾发出哪些警告，此后又发生了什么。", rsch_all: "全部 {n} 条警告 →", rsch_card: "三条警告及其现状", rsch_n: "{n} 份相符案例",
    alerts_h2: "获取提醒", alerts_sub: "每个核实案例，发布即推送。", tg_p: "每个核实案例都会即时发布。", bs_p: "关注 @aithreat.io，获取每个核实案例。", follow: "关注", rss_h: "RSS 与数据", rss_p: "按严重程度、类型和国家划分的订阅源，以及 JSON 格式的完整数据集。", all_feeds: "全部订阅源"
  },
  "ru" => {
    hm_h1: "Все проверенные инциденты безопасности ИИ — с источниками",
    hm_lede: "Открытый реестр атак на системы ИИ и атак с помощью ИИ. Обновляется каждые 30 минут; перед публикацией всё сверяется с первоисточниками.",
    hm_countries: "Страны",
    latest_h: "Последние проверенные случаи", latest_sub: "Пять самых свежих проверенных случаев — по дате, когда о них сообщили.", read_case: "Читать карточку →",
    news_h: "Новостная лента", news_sub: "Свежие материалы из {n} источников — до проверки редактором.", news_all: "Открыть ленту →",
    map_h: "Карта", map_sub: "Все случаи по месту. Цвет метки — наивысший уровень критичности, размер — число случаев.",
    trends_h: "Тенденции", trends_sub: "Как меняется реестр.", trends_all: "Все тенденции →", month_h: "Случаи по месяцам", types_h: "Самые частые типы",
    rsch_h: "Исследования и реальность", rsch_sub: "О чём предупреждали исследователи рисков ИИ и что произошло с тех пор.", rsch_all: "Все {n} предупреждений →", rsch_card: "Три предупреждения и их статус", rsch_n: "Совпадающих карточек: {n}",
    alerts_h2: "Получать оповещения", alerts_sub: "Каждый проверенный случай — сразу после публикации.", tg_p: "Мгновенный пост о каждом проверенном случае.", bs_p: "Подпишитесь на @aithreat.io, чтобы видеть каждый проверенный случай.", follow: "Подписаться", rss_h: "RSS и данные", rss_p: "Ленты по критичности, типу и стране, а также полный набор данных в JSON.", all_feeds: "Все ленты"
  }
}.freeze
