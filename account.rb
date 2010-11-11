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
mykey = File.open("keys/key.pub").read().gsub(" ","").gsub(/-.*?-/,"").gsub("\n","")
credit = {}
address_book = YAML.load_file('address.yaml')
database = YAML.load_file('database.yaml')
debt = {}
keyring = []
all_docs = open("http://#{database["host"]}/#{database["db"]}/_all_docs")
records = all_docs.read()
json_records = JSON.parse(records)
json_records["rows"].each() do |record|
  next if record["id"] =~ /_design/
  document = open("http://#{database["host"]}/#{database["db"]}/#{record["id"]}").read()
  json_document = JSON.parse(document)
  ower_key = json_document["ower_key"].gsub(" ","").gsub(/-.*?-/,"").gsub("\n","")
  owed_key = json_document["owed_key"].gsub(" ","").gsub(/-.*?-/,"").gsub("\n","")
  
  
  if ower_key == mykey
    sig = json_document["sig"].to_a().pack("H*")
    verified = @verifier.verify(sig,json_document["_id"])
    if !verified
      next
    end
    debt[owed_key] ||= 0
    debt[owed_key] += json_document["amount"].to_i()
  end
  
  if owed_key == mykey
    credit[ower_key] ||= 0
    credit[ower_key] += json_document["amount"].to_i()
  end
  
  
end

debt.each_pair() do |owed,amount|
  person = address_book.select{|person| person["public_key"].gsub(" ","").gsub(/-.*?-/,"").gsub("\n","") == owed }
  if person.empty?
    name = owed
  else
    name = person.first()["name"]
    paypal = person.first()["paypal"]
  end
  puts "You owe #{name} (#{paypal}) #{amount}"
end

credit.each_pair() do |ower,amount|
  person = address_book.select{|person|  person["public_key"].gsub(" ","").gsub(/-.*?-/,"").gsub("\n","") == ower }
    if person.empty?
    name = ower
  else
    name = person.first()["name"]
    paypal = person.first()["paypal"]
  end
  puts "#{name} (#{paypal}) owes you #{amount}"
end
