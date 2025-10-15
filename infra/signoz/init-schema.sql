-- ============================================
-- SigNoz Complete Schema for Standalone Deployment
-- ============================================

-- Criar databases
CREATE DATABASE IF NOT EXISTS signoz_traces;
CREATE DATABASE IF NOT EXISTS signoz_logs;
CREATE DATABASE IF NOT EXISTS signoz_metrics;

-- ============================================
-- TRACES TABLES
-- ============================================

-- Top level operations
CREATE TABLE IF NOT EXISTS signoz_traces.top_level_operations (
    name LowCardinality(String),
    serviceName LowCardinality(String),
    time DateTime DEFAULT now()
) ENGINE = MergeTree
ORDER BY (serviceName, name, time);

CREATE VIEW IF NOT EXISTS signoz_traces.distributed_top_level_operations AS 
SELECT * FROM signoz_traces.top_level_operations;

-- Duration sort table (for traces page)
CREATE TABLE IF NOT EXISTS signoz_traces.durationSort (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    traceID String CODEC(ZSTD(1)),
    spanID String CODEC(ZSTD(1)),
    parentSpanID String CODEC(ZSTD(1)),
    serviceName LowCardinality(String) CODEC(ZSTD(1)),
    name LowCardinality(String) CODEC(ZSTD(1)),
    kind Int8,
    durationNano UInt64,
    statusCode Int16,
    httpMethod LowCardinality(String),
    httpUrl String,
    httpRoute String,
    httpHost String,
    hasError Bool,
    tagMap Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    stringTagMap Map(String, String) CODEC(ZSTD(1)),
    numberTagMap Map(String, Float64) CODEC(ZSTD(1)),
    boolTagMap Map(String, Bool) CODEC(ZSTD(1)),
    resourceTagsMap Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    INDEX idx_trace_id traceID TYPE bloom_filter GRANULARITY 4,
    INDEX idx_service serviceName TYPE bloom_filter GRANULARITY 4,
    INDEX idx_name name TYPE bloom_filter GRANULARITY 4,
    INDEX idx_kind kind TYPE set(10) GRANULARITY 4,
    INDEX idx_duration durationNano TYPE minmax GRANULARITY 1,
    INDEX idx_httpRoute httpRoute TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpUrl httpUrl TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpHost httpHost TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpMethod httpMethod TYPE bloom_filter GRANULARITY 4,
    INDEX idx_timestamp timestamp TYPE minmax GRANULARITY 1
) ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (serviceName, hasError, toStartOfHour(timestamp), durationNano, timestamp)
TTL toDateTime(timestamp) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_traces.distributed_durationSort AS 
SELECT * FROM signoz_traces.durationSort;

-- Signoz index v2
CREATE TABLE IF NOT EXISTS signoz_traces.signoz_index_v2 (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    traceID String CODEC(ZSTD(1)),
    spanID String CODEC(ZSTD(1)),
    parentSpanID String CODEC(ZSTD(1)),
    serviceName LowCardinality(String) CODEC(ZSTD(1)),
    name LowCardinality(String) CODEC(ZSTD(1)),
    kind Int8,
    durationNano UInt64,
    statusCode Int16,
    httpMethod LowCardinality(String),
    httpUrl String,
    httpRoute String,
    httpHost String,
    hasError Bool,
    tagMap Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    stringTagMap Map(String, String) CODEC(ZSTD(1)),
    numberTagMap Map(String, Float64) CODEC(ZSTD(1)),
    boolTagMap Map(String, Bool) CODEC(ZSTD(1)),
    resourceTagsMap Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    isRemote LowCardinality(String),
    statusMessage String,
    statusCodeString String,
    gRPCMethod LowCardinality(String),
    gRPCCode LowCardinality(String),
    rpcSystem LowCardinality(String),
    rpcService LowCardinality(String),
    rpcMethod LowCardinality(String),
    responseStatusCode LowCardinality(String),
    externalHttpMethod LowCardinality(String),
    externalHttpUrl String,
    component LowCardinality(String),
    dbSystem LowCardinality(String),
    dbName LowCardinality(String),
    dbOperation LowCardinality(String),
    peerService LowCardinality(String),
    events Array(String),
    INDEX idx_trace_id traceID TYPE bloom_filter GRANULARITY 4,
    INDEX idx_service serviceName TYPE bloom_filter GRANULARITY 4,
    INDEX idx_name name TYPE bloom_filter GRANULARITY 4,
    INDEX idx_kind kind TYPE set(10) GRANULARITY 4,
    INDEX idx_duration durationNano TYPE minmax GRANULARITY 1,
    INDEX idx_httpRoute httpRoute TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpUrl httpUrl TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpHost httpHost TYPE bloom_filter GRANULARITY 4,
    INDEX idx_httpMethod httpMethod TYPE bloom_filter GRANULARITY 4,
    INDEX idx_timestamp timestamp TYPE minmax GRANULARITY 1
) ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (serviceName, hasError, toStartOfHour(timestamp), durationNano, timestamp)
TTL toDateTime(timestamp) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_traces.distributed_signoz_index_v2 AS 
SELECT * FROM signoz_traces.signoz_index_v2;

-- ============================================
-- LOGS TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS signoz_logs.logs (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    observed_timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    id String CODEC(ZSTD(1)),
    trace_id String CODEC(ZSTD(1)),
    span_id String CODEC(ZSTD(1)),
    trace_flags UInt32,
    severity_text LowCardinality(String) CODEC(ZSTD(1)),
    severity_number UInt8,
    body String CODEC(ZSTD(2)),
    resources_string_key Array(String) CODEC(ZSTD(1)),
    resources_string_value Array(String) CODEC(ZSTD(1)),
    attributes_string_key Array(String) CODEC(ZSTD(1)),
    attributes_string_value Array(String) CODEC(ZSTD(1)),
    attributes_int64_key Array(String) CODEC(ZSTD(1)),
    attributes_int64_value Array(Int64) CODEC(ZSTD(1)),
    attributes_float64_key Array(String) CODEC(ZSTD(1)),
    attributes_float64_value Array(Float64) CODEC(ZSTD(1)),
    INDEX body_idx body TYPE tokenbf_v1(10240, 3, 0) GRANULARITY 4,
    INDEX severity_number_idx severity_number TYPE set(25) GRANULARITY 4,
    INDEX severity_text_idx severity_text TYPE set(25) GRANULARITY 4
) ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (timestamp, id)
TTL toDateTime(timestamp) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_logs.distributed_logs AS 
SELECT * FROM signoz_logs.logs;

-- Tag attributes for logs
CREATE TABLE IF NOT EXISTS signoz_logs.tag_attributes (
    timestamp DateTime CODEC(DoubleDelta, LZ4),
    tagKey LowCardinality(String) CODEC(ZSTD(1)),
    tagType Enum8('tag' = 1, 'resource' = 2) CODEC(ZSTD(1)),
    dataType Enum8('string' = 1, 'int64' = 2, 'float64' = 3, 'bool' = 4) CODEC(ZSTD(1)),
    stringValue String CODEC(ZSTD(1)),
    int64Value Int64 DEFAULT 0 CODEC(ZSTD(1)),
    float64Value Float64 DEFAULT 0 CODEC(ZSTD(1)),
    isColumn Bool DEFAULT false CODEC(ZSTD(1))
) ENGINE = ReplacingMergeTree
ORDER BY (tagKey, tagType, dataType, stringValue)
TTL toDateTime(timestamp) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1;

CREATE VIEW IF NOT EXISTS signoz_logs.distributed_tag_attributes AS 
SELECT * FROM signoz_logs.tag_attributes;

-- ============================================
-- METRICS TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS signoz_metrics.time_series_v4 (
    metric_name LowCardinality(String) CODEC(ZSTD(1)),
    fingerprint UInt64 CODEC(Delta, ZSTD(1)),
    timestamp_ms Int64 CODEC(Delta, ZSTD(1)),
    value Float64 CODEC(ZSTD(1)),
    INDEX idx_fingerprint fingerprint TYPE bloom_filter GRANULARITY 4
) ENGINE = MergeTree
PARTITION BY toDate(toDateTime(timestamp_ms / 1000))
ORDER BY (metric_name, fingerprint, timestamp_ms)
TTL toDateTime(timestamp_ms / 1000) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_metrics.distributed_time_series_v4 AS 
SELECT * FROM signoz_metrics.time_series_v4;

-- Time series 1 day aggregation
CREATE TABLE IF NOT EXISTS signoz_metrics.time_series_v4_1day (
    metric_name LowCardinality(String) CODEC(ZSTD(1)),
    fingerprint UInt64 CODEC(Delta, ZSTD(1)),
    timestamp_ms Int64 CODEC(Delta, ZSTD(1)),
    value Float64 CODEC(ZSTD(1)),
    INDEX idx_fingerprint fingerprint TYPE bloom_filter GRANULARITY 4
) ENGINE = MergeTree
PARTITION BY toDate(toDateTime(timestamp_ms / 1000))
ORDER BY (metric_name, fingerprint, timestamp_ms)
TTL toDateTime(timestamp_ms / 1000) + INTERVAL 30 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_metrics.distributed_time_series_v4_1day AS 
SELECT * FROM signoz_metrics.time_series_v4_1day;

-- Time series 1 hour aggregation
CREATE TABLE IF NOT EXISTS signoz_metrics.time_series_v4_1hour (
    metric_name LowCardinality(String) CODEC(ZSTD(1)),
    fingerprint UInt64 CODEC(Delta, ZSTD(1)),
    timestamp_ms Int64 CODEC(Delta, ZSTD(1)),
    value Float64 CODEC(ZSTD(1)),
    INDEX idx_fingerprint fingerprint TYPE bloom_filter GRANULARITY 4
) ENGINE = MergeTree
PARTITION BY toDate(toDateTime(timestamp_ms / 1000))
ORDER BY (metric_name, fingerprint, timestamp_ms)
TTL toDateTime(timestamp_ms / 1000) + INTERVAL 15 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_metrics.distributed_time_series_v4_1hour AS 
SELECT * FROM signoz_metrics.time_series_v4_1hour;

-- Samples table
CREATE TABLE IF NOT EXISTS signoz_metrics.samples_v4 (
    metric_name LowCardinality(String) CODEC(ZSTD(1)),
    fingerprint UInt64 CODEC(Delta, ZSTD(1)),
    timestamp_ms Int64 CODEC(Delta, ZSTD(1)),
    value Float64 CODEC(ZSTD(1))
) ENGINE = MergeTree
PARTITION BY toDate(toDateTime(timestamp_ms / 1000))
ORDER BY (metric_name, fingerprint, timestamp_ms)
TTL toDateTime(timestamp_ms / 1000) + INTERVAL 7 DAY DELETE
SETTINGS ttl_only_drop_parts = 1, index_granularity = 8192;

CREATE VIEW IF NOT EXISTS signoz_metrics.distributed_samples_v4 AS 
SELECT * FROM signoz_metrics.samples_v4;
