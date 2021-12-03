require "./spec_helper"

describe PrometheusExporter::Client do
  describe "#default" do
    it "returns default client" do
      PrometheusExporter::Client.default.class.should eq PrometheusExporter::Client
    end

    it "returns custom client" do
      client = PrometheusExporter::Client.new(
        host: "http://127.0.0.1",
        port: "9395",
      )
      PrometheusExporter::Client.default = client

      PrometheusExporter::Client.default.should eq client
    end

    it "contains valid settings" do
      client = PrometheusExporter::Client.new(
        host: "http://127.0.0.1",
        port: "9395",
      )
      PrometheusExporter::Client.default = client

      PrometheusExporter::Client.default.host.should eq "http://127.0.0.1"
      PrometheusExporter::Client.default.port.should eq "9395"
    end
  end

  describe "#register" do
    it "returns new metric" do
      metric = PrometheusExporter::Client.default.register(
        type: :counter,
        name: :test1,
        description: "Test metric."
      )

      metric.class.should eq PrometheusExporter::Metric::RemoteMetric
    end

    it "contains valid attributes" do
      metric = PrometheusExporter::Client.default.register(
        type: :counter,
        name: :test2,
        description: "Test metric."
      )

      metric.name.should eq :test2
      metric.type.should eq :counter
      metric.description.should eq "Test metric."
    end

    it "raises exception when metric already registered" do
      expect_raises(PrometheusExporter::AlreadyRegisteredError, "Metric test1 already registered") do
        PrometheusExporter::Client.default.register(type: :counter, name: :test1)
      end
    end
  end

  describe "#find" do
    it "returns metric" do
      begin
        PrometheusExporter::Client.default.register(
          type: :counter,
          name: :test1,
          description: "Test metric."
        )
      rescue exception
      end

      PrometheusExporter::Client.default.find(:test1).class.should eq PrometheusExporter::Metric::RemoteMetric
    end

    it "returns nil" do
      PrometheusExporter::Client.default.find(:dutch_van_der_linde).should eq nil
    end
  end

  describe "#observe" do
    # TODO: more specs

    it "raises exception" do
      expect_raises(PrometheusExporter::NotRegisteredError, "Metric dutch_van_der_linde not registered") do
        PrometheusExporter::Client.default.observe(name: :dutch_van_der_linde, value: 1.0)
      end
    end
  end
end
