# Operational Analysis Report
**Name:** Althea Barbato

## What's running

Three new Docker containers added on top of what the previous labs left behind:

- **Prometheus** (port 9090) — scrapes metrics every 15s from node_exporter, nginx_exporter, and itself
- **Grafana** (port 3000) — dashboards on top of Prometheus, also shows the alert state in its own alerting view
- **nginx_exporter** — reads nginx's stub_status endpoint, turns request rate and connection counts into Prometheus metrics

All deployed the same way as before — Ansible playbooks, same server, idempotent.

The Grafana dashboard is provisioned as code in the repo, not manually clicked together, so it'd recreate itself automatically if Grafana ever had to be redeployed.

## What the metrics are actually showing

Pulled live from Prometheus:

| Metric | Value |
|---|---|
| CPU usage | 0.67% |
| Memory usage | 7.75% |
| Disk usage (root) | 11.35% |
| NGINX requests/sec | ~0.07 |

CPU and memory are both really low which makes sense since this server isn't under any actual load — just nginx, some docker containers, fail2ban, rsyslog, and cron running quietly. 7.75% of 11GB is roughly 850MB across everything.

Disk is fine at 11.35% (about 5GB of 45GB used). Worth keeping an eye on though since Prometheus time series data in `/var/lib/prometheus` grows over time. Set the retention to 7 days so it'll cap out instead of filling the disk.

The nginx request rate is basically zero because nobody's hitting this server except me testing things. In a real deployment that number would tell you if traffic looks normal or something weird is happening.

## Alerts configured

Three rules set up in Prometheus:

**InstanceDown** (critical) — fires if any scrape target is unreachable for 30s. This is the one I actually demonstrated — stopped node_exporter on purpose, and after the 30 second `for:` window it flipped from Pending to Firing in the Prometheus alerts UI. Restarting node_exporter cleared it.

**HighCPUUsage** (warning) — fires if CPU stays above 80% for a minute. Not firing right now obviously with CPU at 0.67%.

**LowDiskSpace** (warning) — fires when root filesystem drops below 15% free. Not firing now but this one could realistically trigger if the server fills up from Prometheus data, nginx logs, or Docker image storage piling up.

## Stuff I noticed from actually looking at the dashboards

The memory panel looks higher than expected at first glance, but most of it is buff/cache — the Linux kernel just uses free RAM for disk caching, which it gives back when something actually needs it. It's not a leak or a problem, just looks alarming if you don't know what you're looking at.

The alert demo also showed something useful about how Prometheus alerting actually works — when node_exporter went down the `up` metric dropped to 0 immediately on the next scrape, but the alert stayed Pending for the full 30 seconds before flipping to Firing. That's the `for:` field in the alert rule doing its job, preventing one bad scrape from setting off an alert. Good to know when you're trying to screenshot it firing — you have to actually wait, it doesn't happen instantly.

## What this is missing vs real production

Alerts fire and show up in the Prometheus and Grafana UIs, but nothing actually notifies anyone. A real setup would need Alertmanager or Grafana's contact points wired up to email/Slack/PagerDuty so someone actually gets woken up. Right now it's detection without notification — useful for visibility but not useful for on-call.

The dashboards are also only showing a tiny slice of time right now since everything was just deployed today. Historical baselines are what make dashboards actually useful for spotting anomalies — right now it's just showing a flat line with no context for what "normal" looks like.
