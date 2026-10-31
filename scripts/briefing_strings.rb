# frozen_string_literal: true
# Labels for the homepage "briefing" layer added on 2026-10-31: the Lens (who you are), Today's briefing,
# Since your last visit, the Threat weather strip and the Check-up tool picker. Six site languages.
# Every sentence states a count or a date from the registry; none gives advice (see aithreat facts-only rule).
# scripts/home_strings.rb merges these into HOME, and scripts/sync_home_strings.rb copies them into site/index.html.

BRIEFING = {
  "en" => {
    lens_h: "Your lens", lens_sub: "Choose who you are. The numbers, the map and the briefing then count the cases that targeted that group.",
    lens_all: "Everyone", lens_on: "Lens: {name}", lens_note: "{n} of {total} verified cases in the last 12 months targeted {name}.", lens_none: "No verified case in the last 12 months targeted {name}.",
    lens_sectors: { "Technology & AI vendors" => "AI and software companies", "Individuals & consumers" => "Individuals and families", "Education & research" => "Schools and universities", "Government & public sector" => "Government and public bodies", "Financial services" => "Banks and finance", "Defence & security" => "Defence and security" },
    brf_h: "Today's briefing", brf_sub: "What the registry records as of {date}.",
    brf_30: "{n} verified cases in the last 30 days, against {p} in the 30 days before.", brf_crit: "{n} of them are rated critical.", brf_crit0: "None of them is rated critical.",
    brf_newest: "Newest verified case: {title}, published {date}.", brf_wire: "{n} wire stories from {s} sources in the last 24 hours, not yet checked by an editor.", brf_wire0: "No new wire stories in the last 24 hours.",
    since_h: "Since your last visit", since_p: "{n} cases verified since your last visit on {date}.", since_0: "No case verified since your last visit on {date}.", since_first: "First visit. The registry holds {n} verified cases.", since_note: "Counted in this browser only; nothing is sent anywhere.",
    wx_h: "Threat weather", wx_sub: "The six most common types of case: the last 30 days against the 30 days before.", wx_rising: "Rising", wx_steady: "Steady", wx_easing: "Easing", wx_now: "last 30 days", wx_prev: "30 days before",
    chk_h: "Check-up", chk_sub: "Pick the AI tools you use. The registry lists the verified cases that involve each one. It counts cases; it does not rate your risk.",
    chk_res: "{n} verified cases involve {tools}, {m} of them in the last 30 days.", chk_none: "No verified case in the registry mentions the selected tools.", chk_pick: "Select at least one tool.",
    chk_latest: "Latest matching cases", chk_map: "Show on the map", chk_clear: "Clear", chk_on: "Map limited to the {n} cases that involve the selected tools.", chk_off: "Show all cases",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "Coding agents (Cursor, Claude Code, Codex)", tool_chatbot: "A customer-facing chatbot", tool_voice: "Video calls and voice (deepfakes)", tool_cloud: "Cloud LLM keys (Bedrock, Azure OpenAI, Vertex)", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "Unchecked", stamp_ok: "Verified"
  },
  "fr" => {
    lens_h: "Votre angle", lens_sub: "Choisissez qui vous êtes. Les chiffres, la carte et le point du jour comptent alors les cas qui ont visé ce groupe.",
    lens_all: "Tout le monde", lens_on: "Angle : {name}", lens_note: "{n} des {total} cas vérifiés des 12 derniers mois ont visé {name}.", lens_none: "Aucun cas vérifié des 12 derniers mois n’a visé {name}.",
    lens_sectors: { "Technology & AI vendors" => "Entreprises d’IA et de logiciel", "Individuals & consumers" => "Particuliers et familles", "Education & research" => "Écoles et universités", "Government & public sector" => "État et organismes publics", "Financial services" => "Banques et finance", "Defence & security" => "Défense et sécurité" },
    brf_h: "Le point du jour", brf_sub: "Ce que le registre consigne au {date}.",
    brf_30: "{n} cas vérifiés sur les 30 derniers jours, contre {p} sur les 30 jours précédents.", brf_crit: "{n} d’entre eux sont classés critiques.", brf_crit0: "Aucun d’entre eux n’est classé critique.",
    brf_newest: "Dernier cas vérifié : {title}, publié le {date}.", brf_wire: "{n} dépêches de {s} sources sur les dernières 24 heures, pas encore vérifiées par un rédacteur.", brf_wire0: "Aucune nouvelle dépêche sur les dernières 24 heures.",
    since_h: "Depuis votre dernière visite", since_p: "{n} cas vérifiés depuis votre dernière visite le {date}.", since_0: "Aucun cas vérifié depuis votre dernière visite le {date}.", since_first: "Première visite. Le registre compte {n} cas vérifiés.", since_note: "Compté dans ce navigateur seulement ; rien n’est envoyé.",
    wx_h: "Météo des menaces", wx_sub: "Les six types de cas les plus fréquents : les 30 derniers jours face aux 30 jours précédents.", wx_rising: "En hausse", wx_steady: "Stable", wx_easing: "En baisse", wx_now: "30 derniers jours", wx_prev: "30 jours précédents",
    chk_h: "Bilan", chk_sub: "Cochez les outils d’IA que vous utilisez. Le registre liste les cas vérifiés qui impliquent chacun d’eux. Il compte des cas ; il n’évalue pas votre risque.",
    chk_res: "{n} cas vérifiés impliquent {tools}, dont {m} sur les 30 derniers jours.", chk_none: "Aucun cas vérifié du registre ne mentionne les outils cochés.", chk_pick: "Cochez au moins un outil.",
    chk_latest: "Derniers cas correspondants", chk_map: "Voir sur la carte", chk_clear: "Effacer", chk_on: "Carte limitée aux {n} cas qui impliquent les outils cochés.", chk_off: "Tous les cas",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "Agents de code (Cursor, Claude Code, Codex)", tool_chatbot: "Un chatbot pour vos clients", tool_voice: "Appels vidéo et voix (deepfakes)", tool_cloud: "Clés de LLM cloud (Bedrock, Azure OpenAI, Vertex)", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "Non vérifié", stamp_ok: "Vérifié"
  },
  "es" => {
    lens_h: "Tu perspectiva", lens_sub: "Elige quién eres. Las cifras, el mapa y el parte del día cuentan entonces los casos que afectaron a ese grupo.",
    lens_all: "Todos", lens_on: "Perspectiva: {name}", lens_note: "{n} de los {total} casos verificados de los últimos 12 meses afectaron a {name}.", lens_none: "Ningún caso verificado de los últimos 12 meses afectó a {name}.",
    lens_sectors: { "Technology & AI vendors" => "Empresas de IA y software", "Individuals & consumers" => "Personas y familias", "Education & research" => "Escuelas y universidades", "Government & public sector" => "Gobierno y organismos públicos", "Financial services" => "Banca y finanzas", "Defence & security" => "Defensa y seguridad" },
    brf_h: "Parte del día", brf_sub: "Lo que el registro consigna a {date}.",
    brf_30: "{n} casos verificados en los últimos 30 días, frente a {p} en los 30 días anteriores.", brf_crit: "{n} de ellos están clasificados como críticos.", brf_crit0: "Ninguno de ellos está clasificado como crítico.",
    brf_newest: "Último caso verificado: {title}, publicado el {date}.", brf_wire: "{n} noticias de {s} fuentes en las últimas 24 horas, aún sin revisar por un editor.", brf_wire0: "Ninguna noticia nueva en las últimas 24 horas.",
    since_h: "Desde tu última visita", since_p: "{n} casos verificados desde tu última visita el {date}.", since_0: "Ningún caso verificado desde tu última visita el {date}.", since_first: "Primera visita. El registro tiene {n} casos verificados.", since_note: "Contado solo en este navegador; no se envía nada.",
    wx_h: "Tiempo de amenazas", wx_sub: "Los seis tipos de caso más frecuentes: los últimos 30 días frente a los 30 anteriores.", wx_rising: "En aumento", wx_steady: "Estable", wx_easing: "En descenso", wx_now: "últimos 30 días", wx_prev: "30 días anteriores",
    chk_h: "Chequeo", chk_sub: "Marca las herramientas de IA que usas. El registro lista los casos verificados que implican a cada una. Cuenta casos; no evalúa tu riesgo.",
    chk_res: "{n} casos verificados implican a {tools}, {m} de ellos en los últimos 30 días.", chk_none: "Ningún caso verificado del registro menciona las herramientas marcadas.", chk_pick: "Marca al menos una herramienta.",
    chk_latest: "Últimos casos coincidentes", chk_map: "Ver en el mapa", chk_clear: "Borrar", chk_on: "Mapa limitado a los {n} casos que implican a las herramientas marcadas.", chk_off: "Todos los casos",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "Agentes de código (Cursor, Claude Code, Codex)", tool_chatbot: "Un chatbot para clientes", tool_voice: "Videollamadas y voz (deepfakes)", tool_cloud: "Claves de LLM en la nube (Bedrock, Azure OpenAI, Vertex)", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "Sin verificar", stamp_ok: "Verificado"
  },
  "ar" => {
    lens_h: "زاويتك", lens_sub: "اختر من أنت. تَعُدّ الأرقام والخريطة وموجز اليوم عندها الحالات التي استهدفت هذه الفئة.",
    lens_all: "الجميع", lens_on: "الزاوية: {name}", lens_note: "{n} من أصل {total} حالة موثّقة في آخر 12 شهرًا استهدفت {name}.", lens_none: "لا حالة موثّقة في آخر 12 شهرًا استهدفت {name}.",
    lens_sectors: { "Technology & AI vendors" => "شركات الذكاء الاصطناعي والبرمجيات", "Individuals & consumers" => "الأفراد والعائلات", "Education & research" => "المدارس والجامعات", "Government & public sector" => "الحكومة والهيئات العامة", "Financial services" => "المصارف والمال", "Defence & security" => "الدفاع والأمن" },
    brf_h: "موجز اليوم", brf_sub: "ما يسجّله السجل بتاريخ {date}.",
    brf_30: "{n} حالة موثّقة في آخر 30 يومًا، مقابل {p} في الثلاثين يومًا السابقة.", brf_crit: "{n} منها مصنّفة حرجة.", brf_crit0: "لا حالة منها مصنّفة حرجة.",
    brf_newest: "أحدث حالة موثّقة: {title}، نُشرت في {date}.", brf_wire: "{n} خبرًا من {s} مصدرًا في آخر 24 ساعة، لم يراجعها محرّر بعد.", brf_wire0: "لا أخبار جديدة في آخر 24 ساعة.",
    since_h: "منذ زيارتك الأخيرة", since_p: "{n} حالة وُثّقت منذ زيارتك الأخيرة في {date}.", since_0: "لم تُوثَّق أي حالة منذ زيارتك الأخيرة في {date}.", since_first: "زيارة أولى. يضم السجل {n} حالة موثّقة.", since_note: "يُحسب في هذا المتصفح فقط؛ لا يُرسل شيء.",
    wx_h: "طقس التهديدات", wx_sub: "أكثر ستة أنواع من الحالات شيوعًا: آخر 30 يومًا مقابل الثلاثين يومًا السابقة.", wx_rising: "في ارتفاع", wx_steady: "مستقر", wx_easing: "في انخفاض", wx_now: "آخر 30 يومًا", wx_prev: "30 يومًا سابقة",
    chk_h: "فحص", chk_sub: "اختر أدوات الذكاء الاصطناعي التي تستخدمها. يعرض السجل الحالات الموثّقة التي تتعلق بكل منها. هو يَعُدّ الحالات ولا يقيّم خطرك.",
    chk_res: "{n} حالة موثّقة تتعلق بـ{tools}، منها {m} في آخر 30 يومًا.", chk_none: "لا حالة موثّقة في السجل تذكر الأدوات المختارة.", chk_pick: "اختر أداة واحدة على الأقل.",
    chk_latest: "أحدث الحالات المطابقة", chk_map: "عرض على الخريطة", chk_clear: "مسح", chk_on: "الخريطة محصورة بالحالات الـ{n} التي تتعلق بالأدوات المختارة.", chk_off: "كل الحالات",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "وكلاء البرمجة (Cursor وClaude Code وCodex)", tool_chatbot: "روبوت محادثة للعملاء", tool_voice: "مكالمات الفيديو والصوت (التزييف العميق)", tool_cloud: "مفاتيح نماذج سحابية (Bedrock وAzure OpenAI وVertex)", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "غير موثّق", stamp_ok: "موثّق"
  },
  "zh" => {
    lens_h: "你的视角", lens_sub: "选择你的身份。数字、地图和今日简报随即只统计针对该群体的案例。",
    lens_all: "所有人", lens_on: "视角：{name}", lens_note: "过去 12 个月的 {total} 起已核实案例中，有 {n} 起针对{name}。", lens_none: "过去 12 个月没有针对{name}的已核实案例。",
    lens_sectors: { "Technology & AI vendors" => "AI 与软件公司", "Individuals & consumers" => "个人与家庭", "Education & research" => "学校与大学", "Government & public sector" => "政府与公共机构", "Financial services" => "银行与金融", "Defence & security" => "国防与安全" },
    brf_h: "今日简报", brf_sub: "截至 {date} 登记在册的情况。",
    brf_30: "过去 30 天有 {n} 起已核实案例，此前 30 天为 {p} 起。", brf_crit: "其中 {n} 起评为严重。", brf_crit0: "其中没有评为严重的案例。",
    brf_newest: "最新核实案例：{title}，{date} 公开。", brf_wire: "过去 24 小时来自 {s} 个来源的 {n} 条快讯，尚未经编辑核对。", brf_wire0: "过去 24 小时没有新快讯。",
    since_h: "自你上次访问以来", since_p: "自你 {date} 上次访问以来新核实 {n} 起案例。", since_0: "自你 {date} 上次访问以来没有新核实的案例。", since_first: "首次访问。登记册共有 {n} 起已核实案例。", since_note: "仅在本浏览器中计数，不会发送任何数据。",
    wx_h: "威胁天气", wx_sub: "最常见的六类案例：过去 30 天与此前 30 天对比。", wx_rising: "上升", wx_steady: "持平", wx_easing: "回落", wx_now: "过去 30 天", wx_prev: "此前 30 天",
    chk_h: "自查", chk_sub: "勾选你使用的 AI 工具。登记册列出涉及每种工具的已核实案例。它只统计案例，不评估你的风险。",
    chk_res: "{n} 起已核实案例涉及{tools}，其中 {m} 起发生在过去 30 天。", chk_none: "登记册中没有已核实案例提到所选工具。", chk_pick: "请至少勾选一种工具。",
    chk_latest: "最新匹配案例", chk_map: "在地图上显示", chk_clear: "清除", chk_on: "地图仅显示涉及所选工具的 {n} 起案例。", chk_off: "显示全部案例",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "编程代理（Cursor、Claude Code、Codex）", tool_chatbot: "面向客户的聊天机器人", tool_voice: "视频通话与语音（深度伪造）", tool_cloud: "云端大模型密钥（Bedrock、Azure OpenAI、Vertex）", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "未核实", stamp_ok: "已核实"
  },
  "ru" => {
    lens_h: "Ваш ракурс", lens_sub: "Выберите, кто вы. Цифры, карта и сводка дня будут считать только случаи, нацеленные на эту группу.",
    lens_all: "Все", lens_on: "Ракурс: {name}", lens_note: "{n} из {total} подтверждённых случаев за последние 12 месяцев были нацелены на {name}.", lens_none: "За последние 12 месяцев нет подтверждённых случаев, нацеленных на {name}.",
    lens_sectors: { "Technology & AI vendors" => "компании ИИ и ПО", "Individuals & consumers" => "частных лиц и семьи", "Education & research" => "школы и университеты", "Government & public sector" => "государство и госорганы", "Financial services" => "банки и финансы", "Defence & security" => "оборону и безопасность" },
    brf_h: "Сводка дня", brf_sub: "Что зафиксировано в реестре на {date}.",
    brf_30: "{n} подтверждённых случаев за последние 30 дней против {p} за предыдущие 30 дней.", brf_crit: "{n} из них оценены как критические.", brf_crit0: "Ни один из них не оценён как критический.",
    brf_newest: "Новейший подтверждённый случай: {title}, опубликован {date}.", brf_wire: "{n} новостей из {s} источников за последние 24 часа, ещё не проверенных редактором.", brf_wire0: "Новых новостей за последние 24 часа нет.",
    since_h: "С вашего прошлого визита", since_p: "{n} случаев подтверждено с вашего прошлого визита {date}.", since_0: "С вашего прошлого визита {date} новых подтверждённых случаев нет.", since_first: "Первый визит. В реестре {n} подтверждённых случаев.", since_note: "Считается только в этом браузере; ничего не отправляется.",
    wx_h: "Погода угроз", wx_sub: "Шесть самых частых типов случаев: последние 30 дней против предыдущих 30.", wx_rising: "Рост", wx_steady: "Без изменений", wx_easing: "Спад", wx_now: "последние 30 дней", wx_prev: "предыдущие 30 дней",
    chk_h: "Проверка", chk_sub: "Отметьте инструменты ИИ, которыми вы пользуетесь. Реестр покажет подтверждённые случаи, связанные с каждым из них. Он считает случаи, а не оценивает ваш риск.",
    chk_res: "{n} подтверждённых случаев связаны с {tools}, из них {m} за последние 30 дней.", chk_none: "Ни один подтверждённый случай в реестре не упоминает отмеченные инструменты.", chk_pick: "Отметьте хотя бы один инструмент.",
    chk_latest: "Последние подходящие случаи", chk_map: "Показать на карте", chk_clear: "Сбросить", chk_on: "На карте только {n} случаев, связанных с отмеченными инструментами.", chk_off: "Все случаи",
    tool_chatgpt: "ChatGPT / OpenAI", tool_claude: "Claude / Anthropic", tool_gemini: "Gemini / Google", tool_copilot: "Microsoft Copilot", tool_coding: "Агенты для кода (Cursor, Claude Code, Codex)", tool_chatbot: "Чат-бот для клиентов", tool_voice: "Видеозвонки и голос (дипфейки)", tool_cloud: "Ключи облачных LLM (Bedrock, Azure OpenAI, Vertex)", tool_deepseek: "DeepSeek", tool_grok: "Grok / xAI", tool_agentforce: "Salesforce Agentforce",
    tape_lbl: "Не проверено", stamp_ok: "Подтверждено"
  }
}.freeze
