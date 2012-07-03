require 'singleton'
require 'deep_merge'
require 'yaml'
require 'fileutils'
require 'net/http'

module Zebra
  class UnsupportedURISchemeException < Exception; end
  class ResourceNotFoundException < Exception; end

  class Config
    include Singleton
    @config = nil
    
    def initialize
      @config = {}
    end

    def read_config_file(config_file)
      if File.exists?(config_file)
        yaml = File.read(config_file)
      else
        raise ResourceNotFoundException.new("Unable to open #{config_file}")
      end
      return yaml
    end

    def config_file= config_file
      @config[:config_file] = config_file

      yaml = read_config_file(config_file)
      config = YAML.load(yaml)
      @config.deep_merge!(config)
      @config.symbolize_keys!
      return @config[:config_file]
    end

    def base_path
      File.expand_path(File.dirname(__FILE__) + '/../../')
    end
    
    def nil?
      return @config.empty?
    end

    def empty?
      return @config.empty?
    end

    def method_missing(id, *args)
      return nil unless @config.instance_of?(Hash)

      method_name = id.id2name
      if method_name =~ /^(.*?)\?$/
        return @config.has_key?($1.to_sym) && !@config[$1.to_sym].nil?
      elsif method_name =~ /^(.*?)\=$/
        return @config[$1.to_sym] = args[0]
      elsif @config.has_key?(method_name.to_sym)
        return @config[method_name.to_sym]
      else
        return nil
      end
    end
  end
end
