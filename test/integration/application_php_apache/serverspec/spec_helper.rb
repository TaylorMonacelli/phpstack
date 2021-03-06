# Encoding: utf-8
require 'serverspec'
require 'net/http'

set :backend, :exec

RSpec.configure do |c|
  c.before :all do
    c.path = '/sbin:/usr/sbin:/bin:/usr/bin'
  end
end

def page_returns(url = 'http://localhost/')
  Net::HTTP.get(URI(url))
end
