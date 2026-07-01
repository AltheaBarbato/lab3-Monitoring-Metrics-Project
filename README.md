# Lab 3 Monitoring & Metrics Project
**Name:** Althea Barbato

Same server again (`webserver01`, `163.192.117.50`). This one adds Prometheus + Grafana on top of everything else, all deployed through Ansible like the last two labs.

## Layout
```
lab3-monitoring/
├── ansible/
│   ├── inventory.ini
│   ├── site.yml
│   ├── vars/main.yml
│   ├── playbooks/
│   │   ├── 01-firewall.yml        opens 9090 + 3000
│   │   ├── 02-metrics-collection.yml   nginx exporter + prometheus
│   │   └── 03-dashboards.yml      grafana
│   └── roles/
│       ├── firewall/
│       ├── nginx_exporter/
│       ├── prometheus/
│       └── grafana/
├── deploy.sh
├── verify.sh
├── alert-demo.sh        stops node_exporter on purpose to fire an alert
└── docs/operational-analysis.md
```
## What's actually collecting metrics

- **node_exporter** - already running from the last lab, system metrics (cpu/mem/disk/network)
- **nginx_exporter** - new, reads nginx's stub_status endpoint, exposes request rate + active connections
- **prometheus** - scrapes all of the above every 15s, also evaluates alert rules
- **grafana** - dashboards on top of prometheus, plus it mirrors prometheus's own alerts in its alerting UI

## Running it

```bash
bash deploy.sh --check
bash deploy.sh
bash verify.sh
```

Grafana's at `http://163.192.117.50:3000` login is `admin` / `lab3monitoring`. The dashboard ("webserver01 Overview") is already provisioned, no manual setup needed.

Prometheus is at `http://163.192.117.50:9090`  `/targets` shows what's being scraped, `/alerts` shows the alert rules and their current state.

## Alerts

Three rules defined in `ansible/roles/prometheus/templates/alert.rules.yml.j2`:
- **InstanceDown** - any scrape target unreachable for 30s
- **HighCPUUsage** - CPU over 80% for a minute
- **LowDiskSpace** - under 15% free on root

## Demonstrating an alert actually firing

```bash
bash alert-demo.sh
```
stops node_exporter, waits for InstanceDown to flip from pending to firing, prints the alert state, gives you time to screenshot, then turns node_exporter back on and confirms it clears.
