def init(env=ENV['RACK_ENV']); end
Encoding.default_internal = 'UTF-8'
require 'rubygems'
require 'bundler/setup'
require 'yaml'
require './lib/base58'
require './lib/notify'
require './lib/photosync'
require 'exifr/jpeg'
Bundler.require

SyncConfig = YAML.load_file('config.yml')

FlickRaw.api_key = SyncConfig['flickr_consumer_key']
FlickRaw.shared_secret = SyncConfig['flickr_consumer_secret']

@flickr = FlickRaw::Flickr.new
@flickr.access_token = SyncConfig['flickr_access_token']
@flickr.access_secret = SyncConfig['flickr_access_token_secret']

PhotoSync.flickr = @flickr
