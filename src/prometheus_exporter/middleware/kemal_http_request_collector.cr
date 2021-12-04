module PrometheusExporter
  module Middleware
    {% if @top_level.has_constant?("Kemal") %}
      class KemalHttpRequestCollector < Kemal::Handler
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

        def call(context : HTTP::Server::Context)
          method = context.request.method
          path = context.request.try(&.path)

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

        private def client
          @client ||= PrometheusExporter::Client.default
        end
      end
    {% else %}
      class KemalHttpRequestCollector; end
    {% end %}
  end
end
