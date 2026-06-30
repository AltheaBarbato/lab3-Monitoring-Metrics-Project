# Operational Analysis Report
**Name:** Althea Barbato

## Monitoring Platform Overview

The monitoring stack is built on three Docker containers all running on webserver01 alongside the services from the previous labs:

- **Prometheus** on port 9090 — scrapes metrics every 15 seconds from three targets: node_exporter (system), nginx_exporter (web traffic), and itself
- **Grafana** on port 3000 — dashboards built on top of Prometheus, also surfaces the Prometheus alert rules in its own alerting view
- **nginx_exporter** — reads nginx's stub_status endpoint and exposes request rate and connection counts as Prometheus metrics

All three deployed via Ansible (playbooks 01-03) same as the previous labs. The dashboard ("webserver01 Overview") is provisioned as code in the repo, not manually configured — which means it'd show up automatically on any new Grafana instance pointed at the same Prometheus data.

## What the metrics are actually showing

Pulled live from Prometheus at time of writing:

| Metric | Current Value |
|---|---|
| CPU usage | 0.67% |
| Memory usage | 7.75% |
| Disk usage (root) | 11.35% |
| NGINX requests/sec | ~0.07 req/s |

CPU and memory are both really low, which makes sense — this server isn't under any real load, it's just running nginx, a few docker containers, fail2ban, rsyslog, and cron. Nothing compute-intensive. The 7.75% memory usage means out of 11GB available, only about 850MB is in use across all services combined.

Disk at 11.35% is fine right now (using about 5GB of the 45GB disk), but it's worth watching — the Prometheus time series data in /var/lib/prometheus will grow over time as metrics accumulate. Set to 7-day retention in the config, so it'll cap out and not just grow forever.

The nginx request rate is barely above zero because nobody's actually hitting this server besides me running test commands. In a real deployment this would tell you whether traffic patterns look normal or whether something's spiking or dropping unexpectedly.

## Alert rules configured

Three alerts defined in Prometheus:

**InstanceDown** (severity: critical) — fires if any scrape target goes unreachable for 30 seconds. Demonstrated this for real by stopping the node_exporter container — it moved from Pending to Firing in the Prometheus alerts UI, then cleared once node_exporter restarted. This is the most important one because it's a catch-all for "something I'm monitoring just disappeared."

**HighCPUUsage** (severity: warning) — fires if average CPU goes over 80% for a full minute. Not triggering currently since CPU is at 0.67%. Would matter for a server under real application load.

**LowDiskSpace** (severity: warning) — fires if root filesystem drops below 15% free. Not triggering now at 11.35% used, but this one is realistic to actually hit over time if the server fills up — Prometheus data, nginx logs, Docker image layers, etc.

## Operational insights

The big takeaway from actually looking at the dashboards vs. just assuming the server is fine: memory usage is low but nonzero, and the distribution is interesting — most of it is buff/cache, not active application memory. That's normal Linux behavior (the kernel aggressively uses free RAM for caching) but it looks scarier than it is if you don't know what you're looking at.

The metrics also confirmed something I suspected but hadn't verified: all four containers from the last lab plus the three new monitoring containers are running comfortably within the server's resources. Nothing is competing for memory or CPU in any meaningful way. If this were a production environment you'd set memory limits on the Docker containers so they can't accidentally starve each other, but for a lab setup it's fine.

The InstanceDown alert demonstration also exposed a subtle thing — after I stopped node_exporter, Prometheus's own "up" metric for that target dropped to 0 immediately on the next scrape, but the alert stayed in "Pending" state for the full 30 seconds before flipping to "Firing." That's by design (the `for: 30s` in the alert rule) and it prevents brief scrape failures from creating alert noise. Worth knowing when you're trying to actually trigger an alert for a screenshot — you have to wait longer than you expect.

## What's missing vs. a real production setup

The notification side of alerting is incomplete — the alerts fire and are visible in both the Prometheus and Grafana UIs, but nothing actually sends a message anywhere. In a real setup you'd wire up an Alertmanager (for Prometheus-native routing) or Grafana's own contact points (email, Slack, PagerDuty) so that a firing alert actually pages someone. The setup here demonstrates the detection side without the notification side, which is fine for a lab but wouldn't be acceptable for anything actually running 24/7.

The dashboard is also only as useful as the period it's been running — after a few hours there's a real time series to look at, but right now some panels only show a tiny sliver of data since everything was just deployed today. A real monitoring setup has historical baselines to compare against; without those, anomaly detection is basically eyeballing it.
