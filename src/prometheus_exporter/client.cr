require "./metric/remote_metric"

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
      @host : String = ENV["COLLECTOR_HOST"]? || "http://localhost",
      @port : String | Int32 = ENV["COLLECTOR_PORT"]? || "9394",
      @custom_labels = Hash(Symbol, String).new,
      @enabled : Bool = true
    )
      @metrics = {} of Symbol => PrometheusExporter::Metric::RemoteMetric
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

    def send_json(obj) : HTTP::Client::Response | Nil
      return unless @enabled

      obj = obj.merge({ custom_labels: @custom_labels }) unless @custom_labels.empty?

      send(obj.to_json)
    end

    private def send(payload) : HTTP::Client::Response | Nil
      HTTP::Client.post(
        "#{@host}:#{@port}/send-metrics",
        body: payload
      )
    rescue exception
      puts exception # TODO: replace by logger

      nil
    end
  end
end
