FROM ruby:2.5-alpine
MAINTAINER UniSender Admin <admin@unisender.com>

ADD . /bot/

RUN gem install bundler -v 2.0.2 \
    && apk add --no-cache \
        mariadb-connector-c \
        mariadb-connector-c-dev \
        build-base \
    && cd /bot \
    && bundle \
    && apk del --no-cache \
        mariadb-connector-c-dev \
        build-base

ENV TELEGRAM_TOKEN=hz \
    DB_HOST=127.0.0.1 \
    DB_PORT=3306 \
    DB_USER=root \
    DB_PASS=docker \
    DB_NAME=helpdeskbot

WORKDIR /bot
ENTRYPOINT ["/usr/local/bundle/bin/bundle", "exec", "/usr/local/bin/ruby", "app.rb"]
