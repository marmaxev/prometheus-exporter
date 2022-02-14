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
        path = context.request.try(&.path)
        path = path ? match_path(method, path) : ""

        t0 = Time.utc
        begin
          call_next(context)
        ensure
          t1 = Time.utc
          status = context.response.status_code.to_s

          if (durations = @durations)
            durations.observe(
              value: (t1 - t0).to_f,
              keys: { :status => status, :method => method, :path => path }
            )
          end

          if (counters = @counters)
            counters.observe(
              value: 1.0,
              keys: { :status => status, :method => method, :path => path }
            )
          end
        end
      end

      private def match_path(method, path)
        {% if @top_level.has_constant?("LuckyRouter") %}
          match = Lucky.router.find_action(method, path)
          return "" unless match

          Lucky.router.routes.find { |route| route[2] == match.payload }.try { |route| route[1] } || ""
        {% else %}
          ""
        {% end %}
      end

      private def client
        @client ||= PrometheusExporter::Client.default
      end
    end
  end
end
