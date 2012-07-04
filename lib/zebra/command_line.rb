require 'optparse'
require 'daemons'

module Zebra

  class MissingArgumentException < Exception; end
  class UnsupportedArgumentException < Exception; end

  #Loads command line options and assigns them to singleton Config object
  class CommandLine
    attr_reader :controller

    def initialize
      Zebra.config.chdir = File.dirname(__FILE__)
      Zebra.config.tmp_dir = '/tmp'
      Zebra.config.daemonize = false

      begin
        @parser = OptionParser.new() do |opts|
          opts.banner = "Usage: #{$0} --config CONFIG [worker|server|queue]"
          
          opts.on('-c', '--config CONFIG', 'Configuration file') do |config_file|
            Zebra.config.config_file = config_file
          end

          opts.on('-d', '--daemonize', 'Daemonize the process') do |daemonize|
            Zebra.config.daemonize = daemonize
          end
          
          opts.on('-p', '--pid-file PID-FILE', 'Pid-File to save the process id') do |pid_file|
            Zebra.config.pid_file = pid_file
          end
            
          opts.on('-l', '--log-file LOG-FILE', 'Log File') do |log_file|
            Zebra.config.log_file = log_file
          end
        end
        @parser.parse!
        Zebra.config.mode = ARGV.shift if ARGV.length > 0
        raise MissingArgumentException.new("Missing --config parameter") unless Zebra.config.config_file?
        raise MissingArgumentException.new("Missing mode of operation: server|proxy|queue") unless Zebra.config.mode?
      rescue SystemExit 
        exit(1)
      rescue MissingArgumentException => e
        puts usage(e)
      rescue ArgumentError => e
        puts usage(e)
      rescue Exception => e
        puts "#{e.class}: #{e.message}"
        puts e.backtrace.join("\n\t")
      end
    end

    def usage(e = nil)
      output = ''
      case e
      when MissingArgumentException
        output += "#{e.message}\n"
      when Exception
        output += "#{e.class}: #{e.message}\n"
      when Nil
        # Do nothing 
      end
      output += @parser.to_s
      output 
    end

    def daemonize
      # Become a daemon
      if RUBY_VERSION < "1.9"
        exit if fork
        Process.setsid
        exit if fork
        Dir.chdir "/" 
        STDIN.reopen "/dev/null"
        STDOUT.reopen "/dev/null", "a" 
        STDERR.reopen "/dev/null", "a" 
      else
        Process.daemon
      end 
    end

    def execute
      #If log file is specified logs messages to that file, else on stdout
      log_file = Zebra.config.log_file
      fh = nil
      if log_file
        fh = File.open(log_file, 'a')
      else
        fh = STDERR
      end

      fh.sync = true
      Zebra.log = Logger.new(fh)

      Zebra.log.datetime_format = "%Y-%m-%d %H:%M:%S"
      Zebra.log.formatter = proc { |severity, datetime, progname, msg| sprintf "%-15s | %5s | %s\n", datetime.strftime(Zebra.log.datetime_format), severity, msg }
      Zebra.config.namespace ||= $0.to_s
  
      # ZMQ sockets are not thread/process safe
      daemonize if Zebra.config.daemonize

      begin
        case Zebra.config.mode.to_sym
        when :server
          config = Zebra.config.server || {}
          config[:logger] = Zebra.log
          @controller = ProxyServer.new
        when :worker
          config = Zebra.config.worker || {}
          config[:logger] = Zebra.log
          @controller = ProxyWorker.new(config)
        when :queue
          config = Zebra.config.queue || {}
          config[:logger] = Zebra.log
          @controller = Queue.new(config)
        else
          raise UnsupportedArgumentException.new("Cannot handle #{Zebra.config.mode} mode")
        end

        
        if Zebra.config.pid_file?
          Zebra.log.debug("Writing pid file #{Zebra.config.pid_file}")
          File.open(Zebra.config.pid_file, 'w') do |f| 
            f.write(Process.pid)
          end
        end


        @controller.dispatch
      rescue Interrupt => e
        Zebra.log.info e.message
      end
    end
  end
end
