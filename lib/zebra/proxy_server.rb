require 'goliath'
require 'goliath/plugins/latency'
require 'em-synchrony'
require 'em-zeromq'
require 'yajl'
require 'json'
require 'base64'

module Zebra
  trap('INT') do
    EM::stop() if EM::reactor_running?
  end

  class Goliath::Server
    def load_config(file = nil)
      config[:context] = EM::ZeroMQ::Context.new(1)
      config[:connection_pool] = EM::Synchrony::ConnectionPool.new(:size => 20) do  
        config[:context].socket(ZMQ::REQ) do |socket|
          socket.connect(Zebra.config.server[:frontend_uri])
        end
      end
    end
  end

  class Goliath::Runner
    def run
      $LOADED_FEATURES.unshift(File.basename($0))
      Dir.chdir(File.expand_path(Zebra.config.chdir))
      @port = 8000
      if Zebra.config.server?
        @port = ::Zebra.config.server[:port]
      end
      run_server
    end
  end

  class ProxyServer < Goliath::API
    attr_accessor :log

    use Goliath::Rack::Tracer             # log trace statistics
    use Goliath::Rack::DefaultMimeType    # cleanup accepted media types
    use Goliath::Rack::Render, 'json'     # auto-negotiate response format
    use Goliath::Rack::Params             # parse & merge query and body parameters
    use Goliath::Rack::Heartbeat          # respond to /status with 200, OK (monitoring, etc)

    # If you are using Golaith version <=0.9.1 you need to Goliath::Rack::ValidationError
    # to prevent the request from remaining open after an error occurs
    #use Goliath::Rack::ValidationError
    use Goliath::Rack::Validation::RequestMethod, %w(GET POST PUT DELETE)           # allow GET and POST requests only

    plugin Goliath::Plugin::Latency       # output reactor latency every second

    def response(env)
      #ap env
      json = env.select { |k,v| v.instance_of?(String) }.to_json
      @log.debug "Sending #{json}"

      config[:connection_pool].execute(false) do |conn|
        handler = EM::Protocols::ZMQConnectionHandler.new(conn)
        reply = handler.send_msg(json).first
        #ap reply
        if reply.eql?('null')
          response = [500, {}, 'Server Error']
        else
          response = JSON.parse(reply)
          response[2] = Base64.decode64(response[2])
        end
        #ap response
        return response
        #[200, {}, resp]
      end
    end

    def initialize(config={})
      super
      @log = config[:logger] || Logger.new(STDERR)
    end

    def dispatch
      # Don't need to do anything, handled by Goliath
    end
  end

  class EM::Protocols::ZMQConnectionHandler
    attr_reader :received

    def initialize(connection)
      @connection = connection
      @client_fiber = Fiber.current
      @connection.setsockopt(ZMQ::IDENTITY, "req-#{@client_fiber.object_id}")
      @connection.handler = self
    end

    def send_msg(*parts)
      queued = @connection.send_msg(*parts)
      @connection.register_readable
      messages = Fiber.yield
      messages.map(&:copy_out_string)
    end

    def on_readable(socket, messages)
      @client_fiber.resume(messages)
    end
  end
end

