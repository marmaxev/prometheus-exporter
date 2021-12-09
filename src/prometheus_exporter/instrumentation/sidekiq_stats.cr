{% if @top_level.has_constant?("Sidekiq") %}
  require "sidekiq/sidekiq/api"
{% end %}

module PrometheusExporter
  module Instrumentation
    {% if @top_level.has_constant?("Sidekiq") %}
      class SidekiqStats
        def self.start(
          client : PrometheusExporter::Client = PrometheusExporter::Client.default,
          frequency : Int = 5
        )
          process_collector = new

          spawn do
            while true
              begin
                client.send_json(process_collector.collect)
              rescue exception
                ::PrometheusExporter::Log.error(exception: exception) {}
              ensure
                sleep frequency
              end
            end
          end
        end

        def collect
          {
            type: "sidekiq_stats",
            stats: collect_stats
          }
        end

        private def collect_stats
          stats = ::Sidekiq::Stats.new

          {
            processed: stats.processed.as_i,
            failed: stats.failed.as_i,
            enqueued: stats.enqueued.as_i,
            scheduled_size: stats.scheduled_size.as_i,
            retry_size: stats.retry_size.as_i,
            dead_size: stats.dead_size.as_i,
            processes_size: stats.processes_size.as_i,
            workers_size: stats.workers_size.as_i
          }
        end
      end
    {% else %}
      class SidekiqStats
        def self.start(**args)
          raise SidekiqModuleNotFound.new("Sidekiq module not found!")
        end
      end
    {% end %}
  end
end
