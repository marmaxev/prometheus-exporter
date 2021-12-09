require "./spec_helper"

describe PrometheusExporter::Instrumentation::Sidekiq do
  describe "#new" do
    it "raise exception when Sidekiq not required" do
      expect_raises(PrometheusExporter::Instrumentation::SidekiqModuleNotFound, "Sidekiq module not found!") do
        PrometheusExporter::Instrumentation::Sidekiq.new(
          client: PrometheusExporter::Client.default
        )
      end
    end
  end
end
