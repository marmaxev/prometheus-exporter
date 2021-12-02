require "./metric/remote_metric"

module PrometheusExporter
  class AlreadyRegisteredError < Exception; end
  class NotRegisteredError < Exception; end
  
  class Client
    def initialize(
      @host : String = ENV["COLLECTOR_HOST"]? || "http://localhost",
      @port : String | Int32 = ENV["COLLECTOR_PORT"]? || "9394",
      @custom_labels = Hash(Symbol, String).new,
      @enabled : Bool = true
    )
      @metrics = [] of Metric::RemoteMetric
    end

    def register(type : Symbol, name : Symbol, description : String) : Metric::RemoteMetric     
      raise AlreadyRegisteredError.new("Metric #{name} already registered") if find(name)

      metric = Metric::RemoteMetric.new(type: type, name: name, description: description, client: self)
      @metrics << metric

      metric
    end

    def find(name : Symbol)
      @metrics.find { |metric| metric.name == name }
    end

    def observe(name : Symbol, value : Float, keys = {} of Symbol => Symbol)
      return unless @enabled

      metric = find(name)
      raise NotRegisteredError.new("Metric #{name} not registered") unless metric

      metric.observe(value, keys)
    end

    def send_json(obj)
      return unless @enabled

      obj = obj.merge({ custom_labels: @custom_labels }) if @custom_labels.present?

      send(obj.to_json)
    end

    private def send(payload)
      HTTP::Client.post(
        "#{@host}:#{@port.to_s}/send-metrics",
        body: payload
      )
    rescue exception
      puts exception
    end

    def self.default
      @@default ||= new
    end

    def self.default=(client)
      @@default = client
    end
  end
end