r = Redis.new
url = "PUT YOUR WEBSITE HERE"
enable :sessions

get "/apikey" do
  uuid = request.cookies["openid"]
  openid = r.get "identity:#{uuid}"
  key = r.get "apikey:#{openid}"
  return key
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
  return "YOU MUST SPECIFY AN OPENID URL DUMMY" unless request.params["openid"]
  identifier = request.params["openid"]
  store = OpenID::Store::Filesystem.new('openid')
  openid_session = {}
  session[:openid] = openid_session
  consumer = OpenID::Consumer.new(openid_session,store)
  check_id = consumer.begin(identifier)
  redirect check_id.redirect_url(url,"#{url}/openid_callback")
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

get "/openid_callback" do
  store = OpenID::Store::Filesystem.new('openid')
  openid_session = session[:openid]
  consumer = OpenID::Consumer.new(openid_session,store)
  openid_response = consumer.complete(request.params,"#{url}/openid_callback")
  puts openid_response.status.class
  identity = request.params["openid.identity"]
  if openid_response.status == :success
    uuid = `uuidgen`.strip
    r.set "uuid:#{identity}", uuid 
    r.set  "identity:#{uuid}", identity
    response.set_cookie("openid", :expires =>  Time.now + 604800, :value => uuid)
    r.sadd "openid_people", identity
    balance = r.get "balance:#{identity}"
    return "Looks good #{identity}, welcome to the site. Your balance is #{balance}"
    
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
  return File.read('public/index.html')
end