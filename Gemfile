source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'mysql2', '~>0.5.2'
gem 'activerecord', '~>5.2', require: 'active_record'
gem 'telegram-bot-ruby', '~>0.10', require: 'telegram/bot'
