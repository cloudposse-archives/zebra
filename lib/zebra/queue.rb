require 'ffi-rzmq'

module Zebra
  class Queue
    attr_accessor :context, :frontend, :backend, :poller, :log, :frontend_uri, :backend_uri
    def initialize(config)
      @log = config[:logger] || Logger.new(STDERR)
      @frontend_uri = config[:frontend_uri] || 'tcp://*:5559'
      @backend_uri = config[:backend_uri] || 'tcp://*:5560'
      @context = ZMQ::Context.new

      # Socket facing clients
      @frontend = context.socket(ZMQ::ROUTER)

      # Socket facing services
      @backend = context.socket(ZMQ::DEALER)
      trap("INT") do
        @log.info "Shutting down."
        @frontend.close unless @frontend.nil?
        @backend.close unless @backend.nil?
        @context.terminate unless @context.nil?
        exit
      end
    end

    def dispatch
      @frontend.bind(@frontend_uri)
      @backend.bind(@backend_uri)
      begin
        # Start built-in device
        @poller = ZMQ::Device.new(ZMQ::QUEUE,frontend,backend)
      rescue Interrupt => e
        @log.info("Caught interrupt signal...")
      end

      @frontend.close
      @backend.close
      @context.terminate
    end
  end
end
