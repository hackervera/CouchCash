require 'rubygems'
require 'redfinger'
require 'openssl'
require 'redis'
require 'open-uri'
require 'json'

def get_public_key(wfid)
  finger = Redfinger.finger(wfid)
  finger.links.each do |link|
    if link["rel"] == "magic-public-key"
      key_text = link["href"]
      key_type, key_value = key_text.split ","
      rsa, modulus, exponent = key_value.split "."
      decoded_exponent = exponent.tr('-_','+/').unpack('m').first
      decoded_modulus = modulus.tr('-_','+/').unpack('m').first
      key = OpenSSL::PKey::RSA.new
      key.e = OpenSSL::BN.new decoded_exponent
      key.n = OpenSSL::BN.new decoded_modulus
      return key
    end
  end
end

def verify_doc(public_key,sig,doc_id)
  return public_key.verify(OpenSSL::Digest::SHA1.new, [sig].pack('H*'), doc_id)
end

def validate_doc(doc_url)
  r = Redis.new
  json = JSON.parse(open(doc_url).read)
  amount_owed = json["amount_owed"]
  amount_ower = json["amount_ower"]
  ower_wfid = json["ower_wfid"]
  owed_wfid = json["owed_wfid"]
  sig = json["sig"]
  doc_id = json["_id"]
  priv_key = OpenSSL::PKey::RSA.new(r.get "private_key:tjgillies")
  
  begin
    amount = priv_key.private_decrypt([amount_owed].pack('H*'))
    person_owed = "me"
  rescue OpenSSL::PKey::RSAError => e
    puts "Catching #{e.inspect}. What is doc_id? #{doc_id}"
    begin
      amount = priv_key.private_decrypt([amount_ower].pack('H*'))
    rescue OpenSSL::PKey::RSAError => e
      puts "Catching #{e.inspect}. Must not be for us. Returning nil"
      return nil
    end
    person_owed = "other"
  end
  
  if person_owed == "me"
    ower = priv_key.private_decrypt([ower_wfid].pack('H*'))
    owed = "#{@username}@projectdaemon.com"
    public_key = get_public_key(ower)
  else
    ower = "#{@username}@projectdaemon.com"
    public_key = get_public_key(owed)
    owed = priv_key.private_decrypt([owed_wfid].pack('H*'))
  end
  
  if verify_doc(public_key, sig, doc_id) == false
    return nil
  end
  
  return [ower, owed, amount]

end

def validate_db(db_url)
  all_docs = JSON.parse(open("#{db_url}/_all_docs").read)["rows"]
  list_of_args = []
  all_docs.each do |doc|
    doc_id = doc["id"]
    
    vals = validate_doc("#{db_url}/#{doc_id}") 
    if vals.nil?
      next
    end
    list_of_args << vals if not doc_id =~ /design/
  end
  return list_of_args
end

def get_username
  r = Redis.new
  uuid = request.cookies["openid"]
  openid = r.get "identity:#{uuid}"
  username = r.get "username:#{uuid}"
  return username
end


