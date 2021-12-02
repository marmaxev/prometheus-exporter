module PrometheusExporter
  module Metric
    class RemoteMetric
      getter name, type, description

      def initialize(
        @name : Symbol,
        @type : Symbol,
        @description : String,
        @client = PrometheusExporter::Client.default
      ); end

      def observe(value : Float = 0, keys = {} of Symbol => Symbol)
        @client.send_json(metric_params(value, keys))
      end

      def metric_params(value, keys)
        {
          type: @type,
          help: @description,
          name: @name,
          keys: keys,
          value: value
        }
      end
    end
  end
end
