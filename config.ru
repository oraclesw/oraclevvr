require 'bundler'

Bundler.require

# Require the sinatra app file
require_relative('oracle_ivr')

# Use Rack::ShowExceptions middleware to display errors
use Rack::ShowExceptions

# Run the sinatra app as an endpoint
run Sinatra::Application