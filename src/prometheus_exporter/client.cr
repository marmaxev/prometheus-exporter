require "./metric/remote_metric"
require "log"
require "json"

module PrometheusExporter
  class AlreadyRegisteredError < Exception; end

  class NotRegisteredError < Exception; end

  class Client
    def self.default
      @@default ||= new
    end

    def self.default=(client)
      @@default = client
    end

    getter host, port

    def initialize(
      @host : String = ENV["COLLECTOR_HOST"]? || "localhost",
      @port : String | Int32 = ENV["COLLECTOR_PORT"]? || "9394",
      @custom_labels = Hash(Symbol, String).new,
      @enabled : Bool = true,
      @worker_sleep : Float32 = 0.5
    )
      @metrics = {} of Symbol => PrometheusExporter::Metric::RemoteMetric
      @queue = [] of String

      # env or error
      HTTP::Client::Log.level = if ENV["PROMETHEUS_EXPORTER_LOG_LEVEL"]?
        ::Log::Severity.new(ENV["PROMETHEUS_EXPORTER_LOG_LEVEL"].to_i)
      else
        ::Log::Severity.new(5)
      end

      worker_thread if @enabled
    end

    def register(type : Symbol, name : Symbol, description : String = "") : PrometheusExporter::Metric::RemoteMetric
      raise AlreadyRegisteredError.new("Metric #{name} already registered") if find(name)

      metric = PrometheusExporter::Metric::RemoteMetric.new(
        type: type,
        name: name,
        description: description,
        client: self
      )
      @metrics[name] = metric

      metric
    end

    def find(name : Symbol) : PrometheusExporter::Metric::RemoteMetric | Nil
      @metrics[name]?
    end

    def observe(name : Symbol, value : Float, keys = {} of Symbol => Symbol)
      return unless @enabled

      metric = find(name)
      raise NotRegisteredError.new("Metric #{name} not registered") unless metric

      metric.observe(value, keys)
    end

    def send_json(obj)
      return unless @enabled

      obj = obj.merge({ custom_labels: @custom_labels }) unless @custom_labels.empty?

      send(obj)
    end

    private def send(payload)
      @queue.push(payload.to_json.to_s)
    rescue exception
      ::PrometheusExporter::Log.error(exception: exception) {}
    end

    private def socket : TCPSocket | Nil
      if (socket = @socket).nil? || socket.closed?
        @socket = TCPSocket.new(@host, @port.to_i)

        if (socket = @socket)
          socket << ("POST /send-metrics HTTP/1.1\r\n")
          socket << ("Transfer-Encoding: chunked\r\n")
          socket << ("Host: #{@host}\r\n")
          socket << ("Connection: Close\r\n")
          socket << ("Content-Type: application/octet-stream\r\n")
          socket << ("\r\n")
        end
      end

      @socket
    rescue exception
      ::PrometheusExporter::Log.error(exception: exception) {}
      sleep(5)

      nil
    end

    private def worker_thread
      spawn do
        while true
          begin
            process_queue
          rescue exception
            ::PrometheusExporter::Log.error(exception: exception) {}
          ensure
            sleep @worker_sleep
          end
        end
      end
    end

    private def process_queue
      return unless conn = socket

      if (message = @queue.pop?)
        conn << (message.bytesize.to_s(16).upcase)
        conn << ("\r\n")
        conn << (message)
        conn << ("\r\n")
      else
        sleep @worker_sleep
      end
    rescue exception
      ::PrometheusExporter::Log.error(exception: exception) {} 

      close_socket
    end

    private def close_socket
      if (conn = socket) && !conn.closed?
        begin
          conn << "0\r\n"
          conn << "\r\n"
          conn.flush
        ensure
          conn.close
        end
      end
    end
  end
end
