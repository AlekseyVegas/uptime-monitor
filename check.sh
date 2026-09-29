#!/usr/bin/env bash
# Проверка доступности сайтов. Пишет в сервисный Telegram-бот ТОЛЬКО при смене
# состояния: «сайт упал» и «сайт снова работает». Пока сайт лежит — повторно
# не спамит. Состояние хранится в status/state.txt (коммитится workflow).
#
# Секреты: TELEGRAM_SERVICE_BOT_TOKEN, TELEGRAM_SERVICE_CHAT_ID.
set -u

SITES_FILE="${SITES_FILE:-sites.txt}"
STATE_FILE="${STATE_FILE:-status/state.txt}"
RETRY_DELAY="${RETRY_DELAY:-45}"
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

notify() {
  local text="$1"
  echo "NOTIFY: $text"
  if [[ -z "${TELEGRAM_SERVICE_BOT_TOKEN:-}" || -z "${TELEGRAM_SERVICE_CHAT_ID:-}" ]]; then
    echo "  (секреты не заданы — сообщение не отправлено)"
    return
  fi
  curl -sS -m 20 -o /dev/null \
    "https://api.telegram.org/bot${TELEGRAM_SERVICE_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_SERVICE_CHAT_ID}" \
    --data-urlencode "text=${text}" || echo "  (Telegram недоступен)"
}

# Возвращает HTTP-код или 000 при сетевой ошибке/таймауте.
probe() {
  curl -s -o /dev/null -m 20 -L --max-redirs 3 -w "%{http_code}" "$1" 2>/dev/null || true
}

prev_state() {
  awk -v n="$1" '$1 == n { print $2 }' "$STATE_FILE"
}

new_state=""
while read -r name url; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue

  code="$(probe "$url")"
  if [[ ! "$code" =~ ^2 ]]; then
    # Одна повторная попытка: не поднимаем тревогу из-за разового сбоя сети.
    sleep "$RETRY_DELAY"
    code="$(probe "$url")"
  fi

  if [[ "$code" =~ ^2 ]]; then now="up"; else now="down"; fi
  was="$(prev_state "$name")"
  was="${was:-up}"
  echo "$name $url: $code ($now, было $was)"

  if [[ "$was" == "up" && "$now" == "down" ]]; then
    reason="HTTP $code"; [[ "$code" == "000" ]] && reason="не отвечает"
    notify "САЙТ УПАЛ: ${name} (${url}) — ${reason}"
  elif [[ "$was" == "down" && "$now" == "up" ]]; then
    notify "Сайт снова работает: ${name}"
  fi

  new_state+="${name} ${now}"$'\n'
done < "$SITES_FILE"

printf "%s" "$new_state" > "$STATE_FILE"
# Раз в неделю меняется — коммит держит репозиторий «живым», иначе GitHub
# отключает расписание в репозитории без активности 60 дней.
date -u +%G-W%V > status/week.txt
