/**
 * SecureVox Call Server - Metrics Collector
 * Sistema di metriche per monitoring e observability
 */

class MetricsCollector {
  constructor() {
    this.counters = new Map();
    this.gauges = new Map();
    this.histograms = new Map();
    this.startTime = Date.now();
  }

  /**
   * Crea un counter
   */
  createCounter(name, help = '') {
    this.counters.set(name, {
      value: 0,
      help,
      created: Date.now()
    });
  }

  /**
   * Incrementa un counter
   */
  incrementCounter(name, value = 1, labels = {}) {
    const counter = this.counters.get(name);
    if (counter) {
      counter.value += value;
      counter.lastUpdated = Date.now();
      counter.labels = { ...counter.labels, ...labels };
    }
  }

  /**
   * Crea un gauge
   */
  createGauge(name, help = '') {
    this.gauges.set(name, {
      value: 0,
      help,
      created: Date.now()
    });
  }

  /**
   * Imposta valore gauge
   */
  setGauge(name, value, labels = {}) {
    const gauge = this.gauges.get(name);
    if (gauge) {
      gauge.value = value;
      gauge.lastUpdated = Date.now();
      gauge.labels = { ...gauge.labels, ...labels };
    }
  }

  /**
   * Crea un histogram
   */
  createHistogram(name, help = '', buckets = [0.1, 0.5, 1, 2.5, 5, 10]) {
    this.histograms.set(name, {
      buckets: new Map(buckets.map(b => [b, 0])),
      sum: 0,
      count: 0,
      help,
      created: Date.now()
    });
  }

  /**
   * Registra valore histogram
   */
  recordHistogram(name, value, labels = {}) {
    const histogram = this.histograms.get(name);
    if (histogram) {
      histogram.sum += value;
      histogram.count += 1;
      histogram.lastUpdated = Date.now();
      histogram.labels = { ...histogram.labels, ...labels };

      // Aggiorna buckets
      for (const [bucket, count] of histogram.buckets) {
        if (value <= bucket) {
          histogram.buckets.set(bucket, count + 1);
        }
      }
    }
  }

  /**
   * Ottieni tutte le metriche in formato Prometheus
   */
  getPrometheusMetrics() {
    let output = '';

    // Counters
    for (const [name, counter] of this.counters) {
      output += `# HELP ${name} ${counter.help}\n`;
      output += `# TYPE ${name} counter\n`;
      output += `${name} ${counter.value}\n\n`;
    }

    // Gauges
    for (const [name, gauge] of this.gauges) {
      output += `# HELP ${name} ${gauge.help}\n`;
      output += `# TYPE ${name} gauge\n`;
      output += `${name} ${gauge.value}\n\n`;
    }

    // Histograms
    for (const [name, histogram] of this.histograms) {
      output += `# HELP ${name} ${histogram.help}\n`;
      output += `# TYPE ${name} histogram\n`;
      
      for (const [bucket, count] of histogram.buckets) {
        output += `${name}_bucket{le="${bucket}"} ${count}\n`;
      }
      output += `${name}_bucket{le="+Inf"} ${histogram.count}\n`;
      output += `${name}_sum ${histogram.sum}\n`;
      output += `${name}_count ${histogram.count}\n\n`;
    }

    // Metriche di sistema
    const uptime = (Date.now() - this.startTime) / 1000;
    output += `# HELP process_uptime_seconds Process uptime in seconds\n`;
    output += `# TYPE process_uptime_seconds gauge\n`;
    output += `process_uptime_seconds ${uptime}\n\n`;

    const memUsage = process.memoryUsage();
    output += `# HELP process_memory_bytes Process memory usage in bytes\n`;
    output += `# TYPE process_memory_bytes gauge\n`;
    output += `process_memory_bytes{type="rss"} ${memUsage.rss}\n`;
    output += `process_memory_bytes{type="heapTotal"} ${memUsage.heapTotal}\n`;
    output += `process_memory_bytes{type="heapUsed"} ${memUsage.heapUsed}\n`;
    output += `process_memory_bytes{type="external"} ${memUsage.external}\n\n`;

    return output;
  }

  /**
   * Ottieni metriche in formato JSON
   */
  getJsonMetrics() {
    const metrics = {
      counters: Object.fromEntries(this.counters),
      gauges: Object.fromEntries(this.gauges),
      histograms: {},
      system: {
        uptime: (Date.now() - this.startTime) / 1000,
        memory: process.memoryUsage(),
        cpu: process.cpuUsage()
      },
      timestamp: new Date().toISOString()
    };

    // Converti histograms per JSON
    for (const [name, histogram] of this.histograms) {
      metrics.histograms[name] = {
        buckets: Object.fromEntries(histogram.buckets),
        sum: histogram.sum,
        count: histogram.count,
        average: histogram.count > 0 ? histogram.sum / histogram.count : 0,
        help: histogram.help
      };
    }

    return metrics;
  }

  /**
   * Reset di tutte le metriche
   */
  reset() {
    for (const counter of this.counters.values()) {
      counter.value = 0;
    }
    for (const gauge of this.gauges.values()) {
      gauge.value = 0;
    }
    for (const histogram of this.histograms.values()) {
      histogram.sum = 0;
      histogram.count = 0;
      for (const bucket of histogram.buckets.keys()) {
        histogram.buckets.set(bucket, 0);
      }
    }
  }

  /**
   * Metriche specifiche per chiamate
   */
  recordCallStart(callType, userId) {
    this.incrementCounter('calls_started_total', 1, { type: callType });
    this.incrementCounter(`calls_started_by_user_${userId}`, 1);
  }

  recordCallEnd(callType, duration, userId) {
    this.incrementCounter('calls_ended_total', 1, { type: callType });
    this.recordHistogram('call_duration_seconds', duration / 1000, { type: callType });
    this.incrementCounter(`calls_ended_by_user_${userId}`, 1);
  }

  recordSignalingEvent(event, sessionId) {
    this.incrementCounter('signaling_events_total', 1, { event });
    this.incrementCounter(`signaling_${event}_total`, 1);
  }

  recordWebSocketConnection(userId) {
    this.incrementCounter('websocket_connections_total', 1);
    this.setGauge('websocket_active_connections', this.getActiveConnections());
  }

  recordWebSocketDisconnection(userId) {
    this.incrementCounter('websocket_disconnections_total', 1);
    this.setGauge('websocket_active_connections', this.getActiveConnections());
  }

  recordError(errorType, endpoint = '') {
    this.incrementCounter('errors_total', 1, { type: errorType, endpoint });
  }

  /**
   * Ottieni numero connessioni attive (mock)
   */
  getActiveConnections() {
    // TODO: Implementare conteggio reale
    return Math.floor(Math.random() * 100);
  }
}

module.exports = MetricsCollector;

