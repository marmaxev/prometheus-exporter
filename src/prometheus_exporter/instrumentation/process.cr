module PrometheusExporter
  module Instrumentation
    class Process
      STATS = {
        :gc_heap_bytes => "GC heap bytes",
        :gc_free_bytes => "GC free bytes",
        :gc_total_bytes => "GC total bytes",
        :gc_unmapped_bytes => "GC unmapped bytes",
        :bytes_since_gc => "Bytes since GC",
        :cpu_seconds => "Total CPU seconds",
        :rss_bytes => "RSS in bytes"
      }

      def self.start(
        client : PrometheusExporter::Client = PrometheusExporter::Client.default,
        type : String = "crystal",
        frequency : Int = 5,
        labels = {} of Symbol => String
      )
        process_collector = new(
          client,
          labels.merge({:type => type, :pid => pid.to_s})
        )

        spawn do
          while true
            begin
              process_collector.collect
            rescue exception
              ::PrometheusExporter::Log.error(exception: exception) {}
            ensure
              sleep frequency
            end
          end
        end
      end

      def self.pid
        ::Process.pid
      end

      def initialize(client, @metric_labels : Hash(Symbol, String))
        @metrics = Hash(Symbol, PrometheusExporter::Metric::RemoteMetric).new

        STATS.each do |k, v|
          @metrics[k] = client.register(:gauge, k, v)
        end
      end

      def collect
        stats = collect_stats

        stats.each do |k, v|
          @metrics[k].observe(v, @metric_labels)
        end
      end

      private def collect_stats
        times = ::Process.times
        gc_stats = GC.stats

        {
          :gc_heap_bytes => gc_stats.heap_size.to_f,
          :gc_free_bytes => gc_stats.free_bytes.to_f,
          :gc_total_bytes => gc_stats.total_bytes.to_f,
          :gc_unmapped_bytes => gc_stats.unmapped_bytes.to_f,
          :bytes_since_gc => gc_stats.bytes_since_gc.to_f,
          :cpu_seconds => times.stime + times.utime,
          :rss_bytes => rss
        }
      end

      # rss size in bytes
      private def rss
        row = `ps -o pid,rss`.split("\n").find { |process| process =~ /#{self.class.pid} / }

        row ? row.split(' ').last.to_f * 1024 : 0.0
      end
    end
  end
end
