# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'redis_move'
# where download your origin code
set :repo_url, 'ssh://xxxxxxxxxxxxxx/sinatra_redis'
# where your branch
set :branch,'flush_code'
# where save your upload project on server
set :deploy_to, '/opt/redis_move'


set :bundle_flags, '--deployment'

set :bundle_gemfile, -> { release_path.join('Gemfile') }

set :chruby_ruby, 'ruby-2.1.3'

set :rvm_ruby_version, 'ruby-2.1.3'

set :stages, %w(staging production)

set :default_stage, "production"

set :scm, :git

set :linked_files, fetch(:linked_files, []).push("config.ru")

# Default value for linked_dirs is []
 set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for keep_releases is 5
 set :keep_releases, 5

namespace :deploy do

  task :start  do
    on roles(:web),in: :sequence, wait: 3 do
      within release_path do
        execute "cd /opt/redis_move/current;bundle exec thin  -P logs/rack.pid  -e production -p 9191 -l logs/thin.log -d start"
      end
    end
  end

  task :stop do
    file_path = File.join("/opt/redis_move/current/logs/rack.pid")
    if File.exist?(file_path) then
      File.open(file_path) do |file|
        pid = file.read
        system("kill -9 #{pid}")
      end
      FileUtils.rm file_path
    end
  end

  task :restart => [:stop, :start]

  after :published, :restart

end
