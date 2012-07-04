require 'rubygems'
require 'ffi-rzmq'
require 'json'
require 'logger'
require 'uuid'
require 'em-zeromq'
require 'em-synchrony'
require 'em-synchrony/em-http'
require 'em-synchrony/fiber_iterator'
require 'fiber'
require 'base64'
require 'preforker'

module Zebra
  class ProxyWorkerReceiveMessageHandler
    attr_reader :received

    def initialize(config)
      @config = config
      @logger = config[:logger] || Logger.new(STDERR)
      @conns = {}
    end

    def to_headers(response_headers)
      raw_headers = {}
      response_headers.select { |k,v| k =~ /^[A-Z0-9_]+$/ }.each_pair { |k,v| raw_headers[ k.downcase.split('_').collect { |e| e.capitalize }.join('-') ] = v}
      raw_headers
    end

    def get_conn(uri)
      conn_key = uri.scheme + '://' + uri.host
      return EM::HttpRequest.new(conn_key, :connect_timeout => 1, :inactivity_timeout => 1)
      if @conns.has_key?(conn_key)
        return @conns[conn_key]
      else
        return @conns[conn_key] = EM::HttpRequest.new(conn_key, :connect_timeout => 1, :inactivity_timeout => 1)
      end
    end

    def fetch(method, uri, request_headers = {})
      @response = nil
      @logger.debug "Proxying #{method} #{uri} #{request_headers.inspect}"
      t_start = Time.now
      conn = get_conn(uri)
      request_headers['Host'] = uri.host
      http = conn.send(method, path: uri.path, query: uri.query, head: request_headers, :keepalive => true)
      @logger.debug "Request finished"
      response_headers = to_headers(http.response_header)
      #ap response_headers
      response_headers['X-Proxied-By'] = 'Zebra'
      response_headers.delete('Connection')
      response_headers.delete('Content-Length')
      response_headers.delete('Transfer-Encoding')
      t_end = Time.now
      elapsed = t_end.to_f - t_start.to_f
      @logger.info "#{elapsed} elapsed"
      @logger.info "Received #{http.response_header.status} from server, #{http.response.length} bytes"
      [http.response_header.status, response_headers, Base64.encode64(http.response)]
    end

    def on_writeable(socket)
      @logger.debug("Writable")
    end

    def handle_message(m)
      #ap m.copy_out_string
      env = JSON.parse(m.copy_out_string)
      uri = URI.parse(env['REQUEST_URI'])
      uri.host = env['HTTP_HOST'] if uri.host.nil? || uri.host.empty?
      uri.path = '/' if uri.path.nil? || uri.path.empty?
      puts env.inspect
      uri.scheme = env['HTTP_X_FORWARDED_PROTO'].downcase if env.has_key?('HTTP_X_FORWARDED_PROTO')
      uri.scheme = 'http' if uri.scheme.nil? || uri.scheme.empty?
      method = env['REQUEST_METHOD'].downcase.to_sym
      puts "uri: #{uri.to_s}"
      fetch(method, uri)
    end

    def on_readable(socket, messages)
      @logger.debug "on_readable #{messages.inspect}"
      fiber = Fiber.new do
        m = messages.first
        response = handle_message(m).to_json
        socket.send_msg response
      end
      fiber.resume
      @logger.debug "Finished on_readable"
    end
  end

  class ProxyWorker
    attr_accessor :log, :workers, :app_name, :timeout

    def initialize(config = {})
      @log = config[:logger] || Logger.new(STDERR)
      @workers = config[:workers] || 10
      @timeout = config[:timeout] || 3600
      @app_name = config[:app_name] || File.basename($0.split(/ /)[0], '.rb')
    end

    def dispatch
      params = { :workers => @workers,
                 :app_name => @app_name,
                 :logger => @log,
                 :timeout => @timeout }
      params[:stdout_path] = Zebra.config.log_file if Zebra.config.log_file?
      params[:stderr_path] = Zebra.config.log_file if Zebra.config.log_file?

      workers = Preforker.new(params) do |master|
        config = {:logger => @log}
        handler = ProxyWorkerReceiveMessageHandler.new(config)
        while master.wants_me_alive? do
          EM.synchrony do
            master.logger.info "Server started..."

            timer = EventMachine::PeriodicTimer.new(5) do
              master.logger.info "ping #{Process.pid}"
            end

            context = EM::ZeroMQ::Context.new(1)
          #  connection_pool = EM::Synchrony::ConnectionPool.new(:size => 1) do  
              socket = context.socket(ZMQ::REP, handler)
              socket.connect(Zebra.config.worker[:backend_uri])
          #  end
          end
        end
      end
      workers.run
    end
  end
end
