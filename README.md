# uptime-monitor

Каждые 10 минут GitHub Actions проверяет сайты из `sites.txt`.
В сервисный Telegram-бот приходит только «САЙТ УПАЛ» и «Сайт снова работает».

- Добавить сайт — строка `имя https://адрес` в `sites.txt`.
- Секреты: `TELEGRAM_SERVICE_BOT_TOKEN`, `TELEGRAM_SERVICE_CHAT_ID`.
- Состояние — `status/state.txt`.
