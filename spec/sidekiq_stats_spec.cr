require "./spec_helper"

describe PrometheusExporter::Instrumentation::SidekiqStats do
  describe "#start" do
    it "raise exception when Sidekiq not required" do
      expect_raises(PrometheusExporter::Instrumentation::SidekiqModuleNotFound, "Sidekiq module not found!") do
        PrometheusExporter::Instrumentation::SidekiqStats.start(
          client: PrometheusExporter::Client.default,
          frequency: 10
        )
      end
    end
  end
end
