require 'core_ext/hash'
require 'zebra/config'
require 'zebra/command_line'
require 'zebra/proxy_server'
require 'zebra/proxy_worker'
require 'zebra/queue'
  
module Zebra
  @@config = Config.instance
  @@log = Logger.new(STDERR)

  def self.config=(config)
    @@config=config
  end

  def self.config
    @@config
  end

  def self.log=(log)
    @@log=log
  end

  def self.log
    @@log
  end
end


