module PrometheusExporter
  module Instrumentation
    class SidekiqModuleNotFound < Exception; end

    {% if @top_level.has_constant?("Sidekiq") %}
      class Sidekiq < Sidekiq::Middleware::ServerEntry
        def initialize(@client : PrometheusExporter::Client = PrometheusExporter::Client.default); end

        def call(job, ctx, &block : -> Bool) : Bool
          success = false
          shutdown = false
          start = Time.utc

          begin
            result = yield
            success = true

            result
          rescue exception
            raise exception
          ensure
            duration = Time.utc - start

            begin
              @client.send_json({
                type: "sidekiq",
                name: job.klass,
                queue: job.queue,
                dead: job.dead?,
                success: success,
                shutdown: shutdown,
                duration: duration.to_f
              })
            rescue exception
              ::PrometheusExporter::Log.error(exception: exception) {}
            end

            result
          end
        end
      end
    {% else %}
      class Sidekiq
        def initialize(**args)
          raise SidekiqModuleNotFound.new("Sidekiq module not found!")
        end
      end
    {% end %}
  end
end
