require 'rubygems'
require 'ezcrypto'
require 'ezsig'
require 'uuid'
require 'typhoeus'
require 'json'
require 'open-uri'
require 'differ'
require 'ezcrypto'
require 'yaml'
require 'ap'
@signer = EzCrypto::Signer.from_file('keys/key.priv')
@verifier = @signer.verifier()
mykey = @signer.public_key().to_s()
credit = {}
address_book = YAML.load_file('address.yaml')
debt = {}
keyring = []
all_docs = open("http://tyler.couchone.com/couchcash/_all_docs")
records = all_docs.read()
json_records = JSON.parse(records)
json_records["rows"].each() do |record|
  next if record["id"] =~ /_design/
  document = open("http://tyler.couchone.com/couchcash/#{record["id"]}").read()
  json_document = JSON.parse(document)
  keyring << json_document["ower_key"]
  keyring << json_document["owed_key"]
  if  mykey =~ /#{json_document["ower_key"]}/
    puts "foo"
  end
  if json_document["ower_key"] == mykey
    sig = json_document["sig"].to_a().pack("H*")
    verified = @verifier.verify(sig,json_document["_id"])
    if !verified
      next
    end
    debt[json_document["owed_key"]] ||= 0
    debt[json_document["owed_key"]] += json_document["amount"].to_i()
  end
  if json_document["owed_key"] == mykey
    credit[json_document["ower_key"]] ||= 0
    credit[json_document["ower_key"]] += json_document["amount"].to_i()
  end
  
end
debt.each_pair() do |owed,amount|
  person = address_book.select{|person| person["public_key"].gsub(" ","").gsub(/-.*?-/,"") == owed.gsub(" ","").gsub(/-.*?-/,"") }
  if person.empty?
    name = owed
  else
    name = person.first()["name"]
    paypal = person.first()["paypal"]
  end
  puts "You owe #{name} (#{paypal}) #{amount}"
end