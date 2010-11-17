require 'rubygems'
require 'bundler'
Bundler.require
require 'ezsig'
require 'sinatra'
require 'redis'
require 'json'
require 'oauth'
require 'openid'
require 'openid/store/memory'
require 'typhoeus'
require 'base64'
require 'cgi'
require 'uuid'
require 'redfinger'
require 'yaml'

config =  YAML::load_file "config.yml"
domain = config["domain"]
couch = config["couch"]

store = OpenID::Store::Memory.new

run Sinatra::Application

if ENV["REDISTOGO_URL"]
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $r = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
else
  $r = Redis.new
end
$r.set "domain", domain
require 'keybuilder'

set :views, File.dirname(__FILE__) + '/views'
set :public, File.dirname(__FILE__) + '/public'

enable :sessions

before do
  if request.cookies["openid"]
    uuid = request.cookies["openid"]
    @username = ($r.get "identity:#{uuid}").split('/')[-1]
  end
end

get "/.well-known/host-meta" do
  @domain = domain
  return erb :xrd
end

get "/validate" do
  @domain = domain
  @couch = couch
  arg_list = validate_db(couch)
  balance = {}
  arg_list.each do |sender, receiver, amount|
    if receiver == "#{@username}@#{@domain}"
      balance[sender] ||= 0
      balance[sender] -= amount.to_i
    else
      balance[receiver] ||= 0
      balance[receiver] += amount.to_i
    end
  end
  content_type :json
  $r.set "balance:#{request.cookies["openid"]}", balance.to_json
  {:ok => "true"}.to_json
end

post "/owe" do
  content_type :json
  return {:error => "bad amount!"}.to_json if params[:amount].nil?
  amount = params[:amount]
  doc_id = UUID.new.generate
  uuid = request.cookies["openid"]
  openid = $r.get "identity:#{uuid}"
  username = $r.get "username:#{uuid}"
  modulus = $r.get "encoded_modulus:#{username}"
  exponent = $r.get "encoded_exponent:#{username}"
  priv_key = OpenSSL::PKey::RSA.new($r.get "private_key:#{username}")
  sig = priv_key.sign(OpenSSL::Digest::SHA1.new, doc_id).unpack('H*').to_s
  public_key = get_public_key(params[:wfid])
  to_wfid = priv_key.public_encrypt(params[:wfid]).unpack('H*').to_s
  from_wfid = public_key.public_encrypt("#{username}@#{domain}").unpack('H*').to_s
  amount_to = public_key.public_encrypt(amount).unpack('H*').to_s
  amount_from = priv_key.public_encrypt(amount).unpack('H*').to_s
  body = { :to_wfid => to_wfid, :from_wfid => from_wfid, :amount_to => amount_to, :amount_from => amount_from, :sig => sig }
  puts body
  response = Typhoeus::Request.put("#{couch}/#{doc_id}", :body => body.to_json, :headers => { :content_type => "application/json" })
  {:ok => "true"}.to_json
end

get "/login" do
  identifier = request.params["openid"]
  openid_session = {}
  session[:openid] = openid_session
  consumer = OpenID::Consumer.new(openid_session,store)
  begin
    check_id = consumer.begin(identifier)
  rescue OpenID::DiscoveryFailure
    halt 403, "Could not find google profile, please create a <a href='http://www.google.com/profiles' target='_blank'>google profile</a>"
  end
  redirect check_id.redirect_url("http://#{domain}","http://#{domain}/openid_callback")
end

get "/uuid" do
  uuid = request.cookies["openid"]
  uuid
end

get "/openid_callback" do
  def gen_keys
    uuid = request.cookies["openid"]
    openid = $r.get "identity:#{uuid}"
    username = $r.get "username:#{uuid}"
    priv_key = OpenSSL::PKey::RSA.generate(4096)
    pub_key = priv_key.public_key
    modulus = priv_key.n.to_s
    exponent = priv_key.e.to_s
    encoded_modulus = [modulus].pack('m').tr('+/','-_').gsub("\n","")
    encoded_exponent = [exponent].pack('m').tr('+/','-_').gsub("\n","")
    $r.set "public_key:#{username}", pub_key
    puts pub_key
    $r.set "private_key:#{username}", priv_key
    puts priv_key
    $r.set "encoded_exponent:#{username}", encoded_exponent
    puts encoded_exponent
    $r.set "encoded_modulus:#{username}", encoded_modulus
    puts encoded_modulus
  end

  openid_session = session[:openid]
  consumer = OpenID::Consumer.new(openid_session,store)
  openid_response = consumer.complete(request.params,"http://#{domain}/openid_callback")
  identity = request.params["openid.identity"]
  username = request.params["openid.claimed_id"].gsub(/.+\/profiles\/(.+?)/, '\1')
  if openid_response.status == :success
    old_ident = $r.get "private_key:#{username}"
    if old_ident.nil?
      puts "generating keys"
      gen_keys
    end

    begin
      uuid = UUID.new.generate
    rescue
      uuid = Time.now.to_i
    end
    $r.set "uuid:#{identity}", uuid 
    $r.set "identity:#{uuid}", identity
    $r.set "username:#{uuid}", username
    response.set_cookie("openid", :expires =>  Time.now + 604800, :value => uuid)
    $r.sadd "openid_people", identity
    redirect "/"
  else
    return "Oops there was an error. We have been notified"
  end
end

get "/balance" do
  content_type :json
  $r.get("balance:#{request.cookies["openid"]}")
end

get "/webfinger/:uri" do
  @username = params[:uri].gsub(/(?:acct:)?([^@]+)@#{Regexp.quote(domain)}/){ $1 }
  @modulus = $r.get "encoded_modulus:#{@username}"
  if @modulus.nil?
    return "User not found"
  end
  @exponent = $r.get "encoded_exponent:#{@username}"
  return erb :webfinger
end

get "/logout" do
  response.delete_cookie('openid')
  redirect "/"
end
  
get "/" do
  @identity = false
  unless @username.nil?
    @identity = @username
  end
  erb :index
end