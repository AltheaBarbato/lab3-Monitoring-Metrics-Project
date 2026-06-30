#!/bin/bash
SERVER_IP="163.192.117.50"
SSH_KEY="$HOME/.ssh/lab1-key.pem"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10"
PASS=0
FAIL=0

check() {
    if [ "$2" = "pass" ]; then
        echo "  [PASS] $1"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $1"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- Containers ---"
for c in prometheus grafana nginx_exporter node_exporter; do
    status=$(ssh $SSH_OPTS "sysadmin@$SERVER_IP" "sudo docker ps --filter name=$c --format '{{.Status}}'" 2>/dev/null)
    [[ "$status" == Up* ]] && check "$c container running" pass || check "$c container running" fail
done

echo "--- Prometheus ---"
prom_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$SERVER_IP:9090/-/ready" 2>/dev/null)
[ "$prom_code" = "200" ] && check "Prometheus ready" pass || check "Prometheus ready (got $prom_code)" fail

targets_up=$(curl -s --connect-timeout 10 "http://$SERVER_IP:9090/api/v1/targets" 2>/dev/null | grep -o '"health":"up"' | wc -l)
[ "$targets_up" -ge 3 ] && check "all Prometheus targets up ($targets_up/3)" pass || check "all Prometheus targets up ($targets_up/3)" fail

echo "--- Grafana ---"
grafana_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://$SERVER_IP:3000/api/health" 2>/dev/null)
[ "$grafana_code" = "200" ] && check "Grafana healthy" pass || check "Grafana healthy (got $grafana_code)" fail

dashboard_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 -u "admin:lab3monitoring" "http://$SERVER_IP:3000/api/dashboards/uid/webserver01-overview" 2>/dev/null)
[ "$dashboard_code" = "200" ] && check "dashboard provisioned" pass || check "dashboard provisioned (got $dashboard_code)" fail

echo "--- Alert rules ---"
alert_rules=$(curl -s --connect-timeout 10 "http://$SERVER_IP:9090/api/v1/rules" 2>/dev/null | grep -o '"name":"InstanceDown"' | wc -l)
[ "$alert_rules" -ge 1 ] && check "alert rules loaded" pass || check "alert rules loaded" fail

echo ""
echo "done — $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
