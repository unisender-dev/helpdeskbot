# Telegram bot for IT HelpDesk

## Features
- Create tickets
- Answer tickets (with pictures and files)
- Rate results
- Operator validation by telegram username

## How to run

Create bot account with @BotFather
```bash
docker build . -t helpdeskbot:latest
mysql -h127.0.0.1 -P3306 -uroot -pdocker -e 'CREATE DATABASE helpdeskbot DEFAULT CHARACTER SET utf8mb4;'
docker run \
    -e TELEGRAM_TOKEN=xxx:yyy \
    -e DB_HOST=127.0.0.1 \
    -e DB_PORT=3306 \
    -e DB_USER=root \
    -e DB_PASS=docker \
    -e DB_NAME=helpdeskbot \
    helpdeskbot:latest
```

## Assign user as operator
```bash
mysql -h127.0.0.1 -P3306 -uroot -pdocker helpdeskbot -e "INSERT INTO admins (username, name) VALUES ('someuser', 'Vasya');"
```

# Questions?

https://t.me/macrosonline
