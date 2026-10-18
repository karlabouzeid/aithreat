# Status history for the Research vs reality warnings: the benchmark over time. Each build reads
# site/data/research_history.json, adds a line for a warning when its status changes, when its
# first real-world case is linked, or on the first build of a new month, and writes the file back.
# It lives under site/ so the robot's commit (`git add -A site`) keeps it; between those events a
# build changes nothing. Strings for the warning pages are in config/research_i18n/history.json.

RESEARCH_HISTORY_PATH = File.join(SITE, "data", "research_history.json")
RESEARCH_HISTORY_I18N = JSON.parse(File.read(File.join(ROOT, "config", "research_i18n", "history.json"), encoding: "UTF-8"))

def record_research_history(research)
  today = Time.now.utc.strftime("%Y-%m-%d")
  hist = File.exist?(RESEARCH_HISTORY_PATH) ? JSON.parse(File.read(RESEARCH_HISTORY_PATH, encoding: "UTF-8")) : {}
  hist["started"] ||= today
  hist["note"] = "One line per warning when its status changes, when its first real-world case is linked, and once a month. CC BY 4.0, AI Threat Watch."
  hist["claims"] ||= {}
  research["claims"].each do |c|
    lines = (hist["claims"][c["id"]] ||= [])
    last = lines.last
    event = if last.nil? then "start"
            elsif last["status"] != c["status"] then "status"
            elsif last["real_world"].to_i.zero? && c["real_world"] > 0 then "first-case"
            elsif last["date"][0, 7] != today[0, 7] then "month"
            end
    lines << { "date" => today, "event" => event, "status" => c["status"], "n" => c["n"], "real_world" => c["real_world"] } if event
    c["history"] = lines
  end
  research["history_started"] = hist["started"]
  File.write(RESEARCH_HISTORY_PATH, JSON.pretty_generate(hist) + "\n")
  research
end

def hx(lang, key, vars = {})
  s = (RESEARCH_HISTORY_I18N[lang] || {})[key.to_s] || RESEARCH_HISTORY_I18N["en"][key.to_s]
  vars.each { |k, v| s = s.gsub("{#{k}}", v.to_s) }
  s
end

def research_history_html(lang, c)
  lines = c["history"] || []
  return "" if lines.empty?
  rows = lines.reverse.map do |e|
    %(<tr><td>#{h(fmt_date(e['date'], lang))}</td><td>#{status_pill(lang, e['status'])}</td><td class="n">#{e['n']}</td><td>#{h(hx(lang, "ev_#{e['event'].tr('-', '_')}"))}</td></tr>)
  end.join
  %(<section class="sec"><h2>#{h(hx(lang, :h))}</h2><div style="overflow-x:auto"><table class="pt"><thead><tr><th>#{h(hx(lang, :date))}</th><th>#{h(hx(lang, :status))}</th><th>#{h(hx(lang, :n))}</th><th>#{h(hx(lang, :event))}</th></tr></thead><tbody>#{rows}</tbody></table></div>) +
    %(<p class="cap">#{h(hx(lang, :c, date: fmt_date(lines.first['date'], lang)))} <a href="/data/research_history.json">research_history.json</a></p></section>)
end
