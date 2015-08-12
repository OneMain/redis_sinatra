require 'rubygems'
require 'sinatra'
require "redis"
require 'sidekiq'
require "json"
require 'sidekiq/api'
# Make sure you have Sinatra installed, then start sidekiq with
# bundle exec sidekiq -r ./app.rb  -L logs/sidekiq.log -d
# Simply run Sinatra with
# ruby app.rb
# and then browse to http://localhost:4567

# operate redis
$redis_save = Redis.new(:host => "Purpose redis ip ", :port => "Purpose redis port ",:password => "Purpose redis passeord")
# read redis
$redis_read = Redis.new(:host => "source redis ip", :port => "source redis port", :password => "source redis password")

get "/" do
  $message = $redis_save.get("redis_move")
  haml :root
end

# delete all data from 18.redis and save need data from 11.redis to 18.reids
get "/flushdb" do
  SinatraWorker.perform_async
  redirect to('/')
end

# get active_creative
get '/redis_move/ACTIVE_CREATIVES' do
  get_ACTIVE_CREATIVES
  @creatice_select = "ACTIVE_CREATIVES"
  haml :index
end
# get fix_creatives
get '/redis_move/FIX_CREATIVES' do
  get_FIX_CREATIVES
  @creatice_select = "FIX_CREATIVES"
  haml :index
end

# get ratio_creatives
get '/redis_move/RATIO_CREATIVES' do
  get_RATIO_CREATIVES
  @creatice_select = "RATIO_CREATIVES"
  haml :index
end
# get cpm_creatives
get '/redis_move/CPM_CREATIVES' do
  get_CPM_CREATIVES
  @creatice_select = "CPM_CREATIVES"
  haml :index
end

# get backfill_creatives
get '/redis_move/BACKFILL_CREATIVES' do
  get_BACKFILL_CREATIVES
  @creatice_select = "BACKFILL_CREATIVES"
  haml :index
end
# get location_creatives
get '/redis_move/LOCATION_CREATIVES' do
  get_LOCATION_CREATIVES
  @creatice_select = "LOCATION_CREATIVES"
  haml :index
end

# get asset_info creatives
get '/redis_move/ASSET_INFO' do
  html = ""
  get_ASSET_INFO.each do |key,value|
    hash_value = JSON.parse(value.split("$").sample(1)[0])
    html += "<a href = '/'>首页</a><br/><form action = /redis_move/update_asset_info method = post><table id = #{key} >"
    hash_value["table"].each_pair do |att_key,att_value|
      unless att_key == 'code'
        html.concat("<tr><td><label>#{att_key}:</label></td><td><input name = #{att_key} value = #{att_value}></input></td></tr>")
      else
        html.concat("<tr><td><label>creative_asset_id:</label></td><td><input name = creative_asset_id value = #{key} ></td></tr><tr><td><label>#{att_key}:</label></td><td><textarea name = #{att_key} rows = 7 cols = 50>#{att_value}</textarea></td></tr>")
      end
    end

    html <<  "</table><br><input type = submit value = 修改><hr/></form>"
  end
  erb :render_view, :locals => {:html => html}
end

# get creative_info
get '/redis_move/CREATIVE_INFO' do
  html = ""
  no_show_key =  ["creativename","created_at","start_date","end_date","updated_at"]
  at_common_line = ["regions","exclude_dates","vast_urls"]
  get_CREATIVE_INFO.each do |key,value|
    hash_value = JSON.parse(value)
    attributes = hash_value["@attributes"]
    html += "<a href = '/'>首页</a><br/><form action = /redis_move/update_creative_info method = post><table id = #{key} >"
    td_count = 0
    attributes.each_pair do |att_key,att_value|
      td_count += 1 unless no_show_key.include?(att_key) || at_common_line.include?(att_key)
      html.concat("<td><label>#{att_key}:</label></td><td><input name = #{att_key}  value =  #{att_value}></input></td>") unless no_show_key.include?(att_key) || at_common_line.include?(att_key)
      html.concat("<tr><td><label>#{att_key}:</label></td><td  colspan =4><textarea name = #{att_key} rows =4 cols = 100> #{att_value}</textarea></td></tr>") if at_common_line.include?(att_key)
      if td_count % 4 == 0 && !at_common_line.include?(att_key)
        html.prepend("<tr>").concat("</tr>")
      end
    end
    html <<  "</table><br><input type = submit value = 修改><hr/></form>"
  end
  erb :render_view, :locals => {:html => html}
end

# UPDATE creative_info
post '/redis_move/update_creative_info' do
  key = params["id"]
  creative_info = $redis_save.hget("CREATIVE_INFO",key)
  hash_value = JSON.parse(creative_info)
  update_creative_info = hash_value["@attributes"].merge(params)
  hash_value["@attributes"] = update_creative_info
  value = hash_value.to_json
  $redis_save.hset("CREATIVE_INFO",key,value)
  redirect to("/redis_move/CREATIVE_INFO")
end

# UPDATE asset_info
post '/redis_move/update_asset_info' do
  key = params["creative_asset_id"]
  update_params = params.reject{ |k| k == "creative_asset_id" }
  update_creative_info = {"table" => update_params}
  value = update_creative_info.to_json
  $redis_save.hset("ASSET_INFO",key,value)
  redirect to("/redis_move/ASSET_INFO")
end

# save  data  to 11.redis
post '/redis_move/create/:creative_select' do
  key = params[:key]
  value = params[:value]
  creative_select = params[:creative_select]
  if $redis_save.HEXISTS(creative_select,key) == 0
    $redis_save.hset(creative_select,key,value)
  end

  redirect to("/redis_move/#{creative_select}")
end

# update data to 11.redis
put '/redis_move/update/:key/:creative_select' do
  key = params[:key]
  value = params[:value]
  creative_select = params[:creative_select]
  $redis_save.hset(creative_select,key,value)
  redirect to("/redis_move/#{creative_select}")
end

# delete data to 11.redis
delete '/redis_move/delete/:key/:creative_select' do
  key = params[:key]
  creative_select = params[:creative_select]
  $redis_save.HDEL(creative_select,key)
  redirect to("/redis_move/#{creative_select}")
end

# save need creative type from 18.redis and save to 11.redis
def save_creatives
  %w{ACTIVE_CREATIVES FIX_CREATIVES RATIO_CREATIVES CPM_CREATIVES BACKFILL_CREATIVES LOCATION_CREATIVES CREATIVE_INFO ASSET_INFO}.each do |key_name|
    i_actives_keys = $redis_read.hkeys(key_name)
    $redis_save.del(key_name)
    i_actives_keys.each do |key|
      $redis_save.hset(key_name,key,$redis_read.hget(key_name,key))
    end
    $redis_save.set("redis_move","#{key_name}_redis_restore_success")
  end
end

# get diff creatives data from 18.redis
%w{ACTIVE_CREATIVES FIX_CREATIVES RATIO_CREATIVES CPM_CREATIVES BACKFILL_CREATIVES LOCATION_CREATIVES  CREATIVE_INFO ASSET_INFO}.each_with_index do |key_name,index|
  define_method "get_#{key_name}" do
    @hash = $redis_save.hgetall(key_name)
  end
end

class SinatraWorker
  include Sidekiq::Worker
  def perform
    save_creatives
  end
end
