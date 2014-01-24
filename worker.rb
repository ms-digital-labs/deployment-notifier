#!/usr/bin/env ruby
require "net/http"
require "httpclient"
trap(:SIGINT){ exit 0 }

Thread.abort_on_exception = true

class RemoteFileMonitor
  def initialize(domain, path)
    @domain = domain
    @path = path
  end

  def wait_for_change
    begin
      @last = fetch
    rescue Net::HTTPServerException
      puts "Got a server error while getting initial value, sleeping"
      sleep 60
      retry
    end

    begin
      sleep 10 until changed?
    rescue Net::HTTPServerException
      puts "Got a server error, sleeping for a while"
      sleep 30
      retry
    end
  end

protected
  def fetch
    response = Net::HTTP.get_response(@domain, @path)
    response.value
    response.body
  end

  def changed?
    new = fetch
    p new
    return false if @last == new
    @last = new
    true
  end
end

path = "/release.txt"

url = ENV["UPDATE_URL"]
client = HTTPClient.new
client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE


ENV["DOMAINS"].split(",").each do |domain|
  Thread.new do
    loop do
      RemoteFileMonitor.new(domain, path).wait_for_change
      client.post(url, "Deploy confirmed: http://#{domain}#{path} has changed")
    end
  end
end

sleep
