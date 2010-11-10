require 'rubygems'
require 'ezcrypto'
require 'ezsig'
require 'uuid'
require 'typhoeus'
require 'json'
require 'yaml'

database = YAML.load_file('database.yaml')
@uuid = UUID.new
@signer = EzCrypto::Signer.from_file('keys/key.priv')
address_book = YAML.load_file('address.yaml')
owed_name = ARGV[0]
person = address_book.select{|person| person["name"] == owed_name }.first()
if person.nil?()
  abort("Person not in address book")
end
uuid = @uuid.generate()
puts uuid
sig = @signer.sign(uuid)
public_key = @signer.public_key()
owed_key = person["public_key"]
ower_key = public_key
amount = ARGV[1]
sig_hex = sig.unpack("H*").to_s()
puts sig_hex
sig_bin = sig_hex.to_a.pack("H*")
body = { :ower_key => ower_key, :owed_key => owed_key, :amount => amount, :sig => sig_hex }.to_json
@response = Typhoeus::Request.put("http://#{database["host"]}/#{database["db"]}/#{uuid}", :body => body, :headers => { :content_type => "application/json" })
puts @response.body()
