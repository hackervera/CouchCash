require 'rubygems'
require 'ezcrypto'
require 'ezsig'
require 'sinatra'
require 'redis'
require 'json'
require 'oauth'
require 'openid'
require 'openid/store/filesystem'
require 'typhoeus'
require 'base64'
require 'cgi'
require 'uuid'
require 'redfinger'
require 'keybuilder'

domain = "YOUR DOMAIN"
couch = "YOUR COUCHDB"
r = Redis.new
run Sinatra::Application
enable :sessions

get "/apikey" do
  uuid = request.cookies["openid"]
  openid = r.get "identity:#{uuid}"
  key = r.get "apikey:#{openid}"
  return key
end

get "/validate" do
  @username = get_username
  arg_list = validate_db(couch)
  arg_list.each do |ower, owed, amount|
    response.write "#{ower} owes #{owed} #{amount}<br>"
  end
  if arg_list.empty?
    response.write "No records"
  end
  response.finish
end


get "/owe/:wfid/:amount" do
  amount = params[:amount]
  def get_public_key(wfid)
    begin
      finger = Redfinger.finger(wfid)
    rescue Redfinger::ResourceNotFound
      halt 403, "There are no webfinger id's at that host"
    rescue NoMethodError
      halt 403, "Unknown Error, please try a different webfinger id"
    end
    finger.links.each do |link|
      if link["rel"] == "magic-public-key"
        key_text = link["href"]
        key_type, key_value = key_text.split ","
        rsa, modulus, exponent = key_value.split "."
        decoded_exponent = Base64.decode64(exponent.tr('-_','+/'))
        decoded_modulus = modulus.tr('-_','+/').unpack('m').first
        begin
          public_key = OpenSSL::PKey::RSA.new
          public_key.e = OpenSSL::BN.new decoded_exponent
          public_key.n = OpenSSL::BN.new decoded_modulus
        rescue OpenSSL::BNError
          halt 403, "Weird key parsing error, we're working on it. Thanks"
        end
        return [public_key, key_value]
      end
    end
    halt 403, "No key found for user"
  end
  doc_id = UUID.new.generate
  uuid = request.cookies["openid"]
  openid = r.get "identity:#{uuid}"
  username = r.get "username:#{uuid}"
  modulus = r.get "encoded_modulus:#{username}"
  exponent = r.get "encoded_exponent:#{username}"
  priv_key = OpenSSL::PKey::RSA.new(r.get "private_key:#{username}")
  sig = priv_key.sign(OpenSSL::Digest::SHA1.new, doc_id).unpack('H*').to_s
  public_key, owed_key = get_public_key(params[:wfid])
  #ower_key = public_key.public_encrypt(["RSA.#{modulus}.#{exponent}"].unpack('H*').to_s)

  if public_key.nil?
    return "That user doesn't exist.... yet"
  end
  owed_wfid = priv_key.private_encrypt(params[:wfid]).unpack('H*').to_s
  ower_wfid = public_key.public_encrypt("#{username}@#{domain}").unpack('H*').to_s
  amount_owed = public_key.public_encrypt(amount).unpack('H*').to_s
  amount_ower = priv_key.private_encrypt(amount).unpack('H*').to_s
  body = { :owed_wfid => owed_wfid, :ower_wfid => ower_wfid, :amount_owed => amount_owed, :amount_ower => amount_ower, :sig => sig }
  response = Typhoeus::Request.put("#{couch}/#{doc_id}", :body => body.to_json, :headers => { :content_type => "application/json" })
  redirect "/validate"
end


get "/newapikey" do
  key = `uuidgen`.strip
  uuid = request.cookies["openid"]
  puts uuid
  openid = r.get "identity:#{uuid}"
  puts openid
  r.set "apikey:#{openid}", key
  r.set "apikey_user:#{key}", openid
  return key
end

get "/trade" do
  names = []
  @uuid = request.cookies["openid"]
  @openid = request.params["openid"]
  openid_uuid = r.get "uuid:#{@openid}"
  if openid_uuid == @uuid
    return "You can't trade with yourself. Sorry"
  end
  @items = r.smembers "items:#{@openid}"
  return erb :trade
end

get "/login" do

  identifier = request.params["openid"]
  
  store = OpenID::Store::Filesystem.new('openid')
  openid_session = {}
  session[:openid] = openid_session
  consumer = OpenID::Consumer.new(openid_session,store)
  check_id = consumer.begin(identifier)
  redirect check_id.redirect_url("http://#{domain}","http://#{domain}/openid_callback")
end

get "/send_coin" do
  uuid = request.cookies["openid"]
  identity = r.get("identity:#{uuid}")
  if identity.nil?
    redirect "/"
  end
  json_request = { :jsonrpc => "1.0", :method => "getnewaddress", :params => [], :id => "yo" }.to_json.to_s
  puts json_request
  bitcoin_response = Typhoeus::Request.post("http://127.0.0.1:8332", :username => "tyler", :password => "tyleriscool", :headers => { :content_type => "plain/text" }, :body => json_request).body
  transaction_address = JSON.parse(bitcoin_response)["result"]
  r.sadd "pending_transactions:#{identity}", transaction_address
  #r.set "transaction_user:#{transaction_address}", identity
  return "Hello #{identity}, please send your coins to #{transaction_address}"
end

get "/uuid" do
  uuid = request.cookies["openid"]
  uuid
end

get "/openid_callback" do
  def gen_keys
    r= Redis.new
    uuid = request.cookies["openid"]
    openid = r.get "identity:#{uuid}"
    username = r.get "username:#{uuid}"
    priv_key = OpenSSL::PKey::RSA.generate(1024)
    pub_key = priv_key.public_key
    modulus = priv_key.n.to_s
    exponent = priv_key.e.to_s
    encoded_modulus = [modulus].pack('m').tr('+/','-_').gsub("\n","")
    encoded_exponent = [exponent].pack('m').tr('+/','-_').gsub("\n","")
    r.set "public_key:#{username}", pub_key
    puts pub_key
    r.set "private_key:#{username}", priv_key
    puts priv_key
    r.set "encoded_exponent:#{username}", encoded_exponent
    puts encoded_exponent
    r.set "encoded_modulus:#{username}", encoded_modulus
    puts encoded_modulus
  end

  store = OpenID::Store::Filesystem.new('openid')
  openid_session = session[:openid]
  consumer = OpenID::Consumer.new(openid_session,store)
  openid_response = consumer.complete(request.params,"http://#{domain}/openid_callback")
  puts openid_response.status.class
  identity = request.params["openid.identity"]
  if openid_response.status == :success
    old_ident = r.get "uuid:#{identity}"
    puts old_ident
    if old_ident.nil?
      puts "generating keys"
      gen_keys
    end

    uuid = `uuidgen`.strip
    r.set "uuid:#{identity}", uuid 
    r.set  "identity:#{uuid}", identity
    username = request.params["openid.claimed_id"].gsub(/.+\/profiles\/(.+?)/, '\1')
    r.set "username:#{uuid}", username
    response.set_cookie("openid", :expires =>  Time.now + 604800, :value => uuid)
    r.sadd "openid_people", identity
    balance = r.get "balance:#{identity}"
    haml :index, :locals => {:identity => identity}
  else
    return "Oops there was an error. We have been notified"
  end
end

get "/balance" do
  apikey = request.params["apikey"]
  identity = r.get "apikey_user:#{apikey}"
  
  if identity
    balance = r.get("balance:#{identity}").to_i
    return { :type => "success", :balance => balance, :identity => identity }.to_json
  else
    return { :type => "error", :message => "could not verify identity" }.to_json
  end
  
  
end

get "/webfinger/:uri" do
  @username = params[:uri].gsub(/(?:acct:)?([^@]+)@#{Regexp.quote(domain)}/){ $1 }
  @modulus = r.get "encoded_modulus:#{@username}"
  if @modulus.nil?
    return "User not found"
  end
  @exponent = r.get "encoded_exponent:#{@username}"
  return erb :webfinger
end
  

get "/transfer" do
  apikey = request.params["apikey"]
  to = request.params["to"]
  amount = request.params["amount"]
  identity = r.get "apikey_user:#{apikey}"
  if identity == to
    return { :type => "error", :message => "You can't transfer to yourself" }.to_json
  end
  balance = r.get "balance:#{identity}"
  to_balance = r.get "balance:#{to}"
  people = r.smembers "openid_people"
  if identity
    if people.include? to
      if amount <= balance
        balance = balance.to_i - amount.to_i
        puts balance
        puts identity
        r.set "balance:#{identity}", balance
      else
        return { :type => "error", :message => "You don't have that much money" }.to_json
      end
      to_balance = to_balance.to_i + amount.to_i
      puts to_balance
      r.set "balance:#{to}", to_balance
      
    else
      return { :type => "error", :message => "#{to} doesn't exist in system" }.to_json
    end
  else
   return { :type => "error", :message => "could not verify identity" }.to_json
  end
  return { :type => "success", :from => identity, :to => to, :amount => amount }.to_json
end

  
get "/" do
  haml :index, :locals => {:identity => false}
end