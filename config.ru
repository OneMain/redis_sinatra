# config.ru
$: << File.expand_path(File.dirname(__FILE__))

require 'app.rb'
run Sinatra::Application