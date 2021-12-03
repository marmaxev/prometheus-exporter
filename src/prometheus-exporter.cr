require "./prometheus_exporter/*"
require "./prometheus_exporter/instrumentation/*"
require "./prometheus_exporter/metric/*"
require "./prometheus_exporter/middleware/*"

module Prometheus::Exporter
  VERSION = "0.1.0"
end
