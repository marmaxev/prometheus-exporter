[![Crystal CI](https://github.com/marmaxev/prometheus-exporter/actions/workflows/crystal.yml/badge.svg?branch=master)](https://github.com/marmaxev/prometheus-exporter/actions/workflows/crystal.yml)

# prometheus-exporter

#### Prometheus metrics for your applications.

This is a client library based on [ruby prometheus exporter](https://github.com/discourse/prometheus_exporter), adapted for applications written in the [Crystal programming language](https://github.com/crystal-lang/crystal).

Allows you to collect and send Prometheus metrics to the server for further use.
Supports several sets of basic metrics for some popular Crystal shards ([Lucky](https://github.com/luckyframework/lucky), [Kemal](https://github.com/kemalcr/kemal) and [Sidekiq](https://github.com/mperham/sidekiq.cr)) and custom metrics.

There is no server application in the project yet, so please use the server from the [original project](https://github.com/discourse/prometheus_exporter).

* [Installation](#installation)
* [Usage](#usage)
  * [Basic example](#basic-example)
  * [Lucky metrics](#lucky-metrics)
  * [Kemal metrics](#kemal-metrics)
  * [Sidekiq metrics](#sidekiq-metrics)
  * [Process metrics](#process-metrics)
  * [Configure client](#configure-client)
* [Contributing](#contributing)
* [Contributors](#contributors)

## Installation

1. Add the dependency to your `shard.yml`:

    ```yaml
    dependencies:
      prometheus-exporter:
        github: marmaxev/prometheus-exporter
    ```

2. Run `shards install`

3. Require prometheus-exporter

    ```crystal
    require "prometheus-exporter"
    ```

## Usage

### Basic example
Define the default client, register metrics and assign values to them.

The default client has `localhost:9394` as the default server address.
```crystal
# use a default client
client = PrometheusExporter::Client.default

# register a new count metric
counter = client.register(
  :counter,
  :my_counter_name,
  "My counter description"
)

# register a new gauge metric
gauge = client.register(
  :gauge,
  :my_gauge_name,
  "My gauge description"
)

# increment counter
counter.observe(1.0)

# observe gauge metric
gauge.observe(
  value: 123.0,
  keys: { :foo => bar }
)
```

You can also observe metrics through the `Client`. For example:
```crystal
client.observe(
  name: :my_gauge_name,
  value: 123.0,
  keys: { :foo => :bar }
)
```

This will allow you to get these metrics on server:
```
# HELP my_gauge_name My gauge description
# TYPE my_gauge_name gauge
my_gauge_name{foo="bar"} 123.0

# HELP my_counter_name My counter description
# TYPE my_counter_name counter
my_counter_name 1.0
```

### Lucky metrics
If you use [Lucky](https://github.com/luckyframework/lucky) you can add a special handler to your server's middleware. Learn more about HTTP handlers in Lucky [here](https://luckyframework.org/guides/http-and-routing/http-handlers).
```crystal
# src/app_server.cr
# ...
class App < Lucky::BaseAppServer
  def middleware
    [
      Lucky::HttpMethodOverrideHandler.new,
      Lucky::LogHandler.new,

      PrometheusExporter::Middleware::LuckyHttpRequestCollector.new,  # add this line

      Lucky::ErrorHandler.new(action: Errors::Show),
      Lucky::RouteHandler.new,
      Lucky::StaticFileHandler.new("./public", false),
      Lucky::RouteNotFoundHandler.new,
    ]
  end
end
```

This handler will process incoming requests and save data about their number and duration.

**PrometheusExporter::Middleware::LuckyHttpRequestCollector**

All metrics have a `status`, `method` and `path` labels.
| Type    | Name                            | Description                             |
| ---     | ---                             | ---                                     |
| Counter | `http_request_count`            | Count of http requests                  |
| Gauge   | `http_request_duration_seconds` | Duration of http requests               |

**Example** of metrics for each request:
```
http_request_count{status="200",method="GET",path="/foo"} 1.0

http_request_duration_seconds{status="200",method="GET",path="/foo"} 0.05
```

### Kemal metrics
If you use [Kemal](https://github.com/kemalcr/kemal) you can add a `KemalHttpRequestCollector` to server's middleware. Learn more about HTTP handlers in Kemal [here](https://kemalcr.com/guide/#middleware).
```crystal
add_handler KemalHttpRequestCollector.new
```

This handler will process incoming requests and save data about their number and duration.

**PrometheusExporter::Middleware::KemalHttpRequestCollector**

All metrics have a `status`, `method` and `path` labels.
| Type    | Name                            | Description                             |
| ---     | ---                             | ---                                     |
| Counter | `http_request_count`            | Count of http requests                  |
| Gauge   | `http_request_duration_seconds` | Duration of http requests               |

**Example** of metrics for each request:
```
http_request_count{status="200",method="GET",path="/bar"} 1.0

http_request_duration_seconds{status="200",method="GET",path="/bar"} 0.1
```

### Sidekiq metrics
There are two sets of metrics being collected for [Sidekiq](https://github.com/mperham/sidekiq.cr).

1. Sidekiq
2. SidekiqStats

When you configure your sidekiq server add `PrometheusExporter::Instrumentation::Sidekiq` to server's middleware and start `PrometheusExporter::Instrumentation::SidekiqStats`.
```crystal
# sidekiq.cr
# ...

cli = Sidekiq::CLI.new
server = cli.configure do |config|
  config.server_middleware.add ::PrometheusExporter::Instrumentation::Sidekiq.new # add this
end

PrometheusExporter::Instrumentation::SidekiqStats.start(frequency: 10) # and this

cli.run(server)
```

**PrometheusExporter::Instrumentation::Sidekiq**

All metrics have a `job_name` label and a `queue` label.
| Type    | Name                           | Description                                                                  |
| ---     | ---                            | ---                                                                          |
| Summary | `sidekiq_job_duration_seconds` | Time spent in sidekiq jobs                                                   |
| Counter | `sidekiq_jobs_total`           | Total number of sidekiq jobs executed                                        |
| Counter | `sidekiq_restarted_jobs_total` | Total number of sidekiq jobs that we restarted because of a sidekiq shutdown |
| Counter | `sidekiq_failed_jobs_total`    | Total number of failed sidekiq jobs                                          |

**PrometheusExporter::Instrumentation::SidekiqStats**
| Type  | Name                            | Description                             |
| ---   | ---                             | ---                                     |
| Gauge | `sidekiq_stats_dead_size`       | Size of the dead queue                  |
| Gauge | `sidekiq_stats_enqueued`        | Number of enqueued jobs                 |
| Gauge | `sidekiq_stats_failed`          | Number of failed jobs                   |
| Gauge | `sidekiq_stats_processed`       | Total number of processed jobs          |
| Gauge | `sidekiq_stats_processes_size`  | Number of processes                     |
| Gauge | `sidekiq_stats_retry_size`      | Size of the retries queue               |
| Gauge | `sidekiq_stats_scheduled_size`  | Size of the scheduled queue             |
| Gauge | `sidekiq_stats_workers_size`    | Number of jobs actively being processed |

### Process metrics
You can also get metrics for each process. To do this, start the `PrometheusExporter::Instrumentation::Process`.
```crystal
PrometheusExporter::Instrumentation::Process.start(
  type: "my_process",
  frequency: 10
)
```

**PrometheusExporter::Instrumentation::Process**

All metrics have a `type` and `pid` labels.
| Type  | Name                | Description       |
| ---   | ---                 | ---               |
| Gauge | `rss_bytes`         | RSS in bytes      |
| Gauge | `cpu_seconds`       | Total CPU seconds |
| Gauge | `bytes_since_gc`    | Bytes since GC    |
| Gauge | `gc_unmapped_bytes` | GC unmapped bytes |
| Gauge | `gc_total_bytes`    | GC total bytes    |
| Gauge | `gc_free_bytes`     | GC free bytes     |
| Gauge | `gc_heap_bytes`     | GC heap bytes     |

### Configure client
By default all of Instrumentations use `PrometheusExporter::Client.default`.

You can configure the server address and port, assign custom labels for all metrics, and specify whether the client is available for use.

```crystal
PrometheusExporter::Client.default = PrometheusExporter::Client.new(
  host: "localhost",
  port: 8000,
  custom_labels: {
    :foo => "bar"
  },
  enabled: true
)
```

## Contributing

1. Fork it (<https://github.com/marmaxev/prometheus-exporter/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [marmaxev](https://github.com/marmaxev)
- [sschekotikhin](https://github.com/sschekotikhin)
