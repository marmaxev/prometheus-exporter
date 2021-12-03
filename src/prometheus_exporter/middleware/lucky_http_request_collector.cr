require "http/server/handler"

module PrometheusExporter
  module Middleware
    class LuckyHttpRequestCollector
      include HTTP::Handler

      getter durations : PrometheusExporter::Metric::RemoteMetric
      getter counters : PrometheusExporter::Metric::RemoteMetric

      def initialize
        @durations = client.register(
          :gauge,
          :http_request_duration_seconds,
          "Duration of HTTP request"
        )
        @counters = client.register(
          :counter,
          :http_request_count,
          "Count of HTTP request"
        )
      end

      def call(context)
        method = context.request.method
        path = context.request.try &.path
        path = path ? match_path(method, path) : ""

        t0 = Time.utc
        begin
          call_next(context)
        ensure
          t1 = Time.utc
          status = context.response.status_code.to_s

          if (durations = @durations)
            durations.observe((t1 - t0).to_f, { :status => status, :method => method, :path => path })
          end

          if (counters = @counters)
            counters.observe(value: 1.0, keys: { :status => status, :method => method, :path => path })
          end
        end
      end

      private def match_path(method, path)
        match = Lucky::Router.find_action(method, path)
        return "" unless match

        Lucky::Router.routes.find { |route| route.action == match.payload }.try(&.path) || ""
      end

      private def client
        @client ||= PrometheusExporter::Client.default
      end
    end
  end
end
