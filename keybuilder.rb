require 'openssl'
require 'open-uri'

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
  amount_to = json["amount_to"]
  amount_from = json["amount_from"]
  to_wfid = json["to_wfid"]
  from_wfid = json["from_wfid"]
  sig = json["sig"]
  doc_id = json["_id"]
  priv_key = OpenSSL::PKey::RSA.new($r.get "private_key:#{@username}")
  
  begin #decrypt amount, ignore doc if can't decrypt either amount value
    amount = priv_key.private_decrypt([amount_to].pack('H*'))
  rescue => e
    begin
      puts e.inspect
      amount = priv_key.private_decrypt([amount_from].pack('H*'))
    rescue => e
      puts e.inspect
      puts "skipping document, couldn't get either amount"
      return nil
    end
  end
  
  begin
    puts e.inspect
    puts "Trying receiver with private_decrypt"
    receiver = priv_key.private_decrypt([to_wfid].pack('H*'))
    sender = "#{@username}@#{@domain}"
  rescue => e
    puts e.inspect
    puts "Trying sender with private_decrypt"
    sender = priv_key.private_decrypt([from_wfid].pack('H*'))
    receiver = "#{@username}@#{@domain}"
  end
  
  public_key = get_public_key(sender)
  if verify_doc(public_key, sig, doc_id) == false
    puts "Failed to verify"
    return nil
  end
  
  puts "#{sender} #{receiver} #{amount}"
  return [sender, receiver, amount]

end

def validate_db(db_url)
  all_docs = JSON.parse(open("#{@couch}/_all_docs").read)["rows"]
  list_of_args = []
  all_docs.each do |doc|
    doc_id = doc["id"]
    vals = validate_doc("#{@couch}/#{doc_id}") 
    if vals.nil?
      next
    end
    list_of_args << vals if not doc_id =~ /design/
  end
  return list_of_args
end

def get_username
  uuid = request.cookies["openid"]
  openid = $r.get "identity:#{uuid}"
  username = $r.get "username:#{uuid}"
  return username
end