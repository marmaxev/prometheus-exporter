require "sidekiq/sidekiq/api"

module PrometheusExporter
  module Instrumentation
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
              puts exception
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
          processed: stats.processed,
          failed: stats.failed,
          enqueued: stats.enqueued,
          scheduled_size: stats.scheduled_size,
          retry_size: stats.retry_size,
          dead_size: stats.dead_size,
          processes_size: stats.processes_size,
          workers_size: stats.workers_size,
        }
      end
    end
  end
end
