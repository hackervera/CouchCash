require 'rubygems'
require 'sinatra'
require 'redis'
require 'json'
require 'oauth'
require 'openid'
require 'openid/store/filesystem'
require 'typhoeus'
require 'application'

run Sinatra::Application