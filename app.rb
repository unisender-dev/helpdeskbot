#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'thread'

$messages = Queue.new
$replies = Queue.new
BOT_TOKEN = ENV.fetch('TELEGRAM_TOKEN', 'hz')

ActiveRecord::Base.establish_connection(
    adapter: 'mysql2',
    encoding: 'utf8mb4',
    collation: 'utf8mb4_bin',
    host: ENV.fetch('DB_HOST', '127.0.0.1'),
    port: ENV.fetch('DB_PORT', '3306').to_i,
    username: ENV.fetch('DB_USER', 'root'),
    password: ENV.fetch('DB_PASS', 'docker'),
    database: ENV.fetch('DB_NAME', 'helpdeskbot'),
    reconnect: true,
    pool: 5,
    connect_timeout: 2,
    keepalives_idle: 30,
    keepalives_interval: 10,
    keepalives_count: 2,
    checkout_timeout: 5,
    reaping_frequency: 10
)
m = ActiveRecord::MigrationContext.new('db/migrate/')
m.migrate
Dir['db/*.rb'].each do |l|
  load l
end

$stop = false

def shutdown
  $stop = true
end

Signal.trap("INT") {
  shutdown
}
Signal.trap("TERM") {
  shutdown
}

Thread.new do
  loop do
    break if $stop
    while $messages.length > 0
      begin
        m = $messages.pop
        if m.from.username
          if a = Admin.find_by(username: m.from.username)
            unless a.check_started(m)
              next
            end
            a.process_message(m)
            next
          end
        end
        if u = User.check_started(m)
          u.process_message(m)
        end
      rescue => e
        puts "[#{e.class}] #{e.message}"
        puts "== #{m.inspect}"
        e.backtrace.each do |line|
          puts "-- #{line}"
        end
        next
      end
    end
    sleep 0.1
  end
end

Telegram::Bot::Client.run(BOT_TOKEN, timeout: 5) do |bot|
  # writer thread
  Thread.new do
    loop do
      break if $stop
      while $replies.length > 0
        data = $replies.pop
        begin
          if data[:photo]
            bot.api.send_photo(data)
          elsif data[:document]
            bot.api.send_document(data)
          else
            bot.api.send_message(data)
          end
        rescue => e
          puts "[#{e.class}] #{e.message}"
          puts "== #{data.inspect}"
          e.backtrace.each do |line|
            puts "-- #{line}"
          end
          next
        end
      end
      sleep 0.1
    end
  end
  loop do
    break if $stop
    bot.listen do |message|
      $messages.push(message)
    end
    sleep 0.1
  end
end
