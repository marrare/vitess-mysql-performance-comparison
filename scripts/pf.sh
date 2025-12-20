#!/usr/bin/env bash

echo "***** INICIANDO PORT FORWARDS (PROMETHEUS, GRAFANA, VITESS) *****"
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector='planetscale.com/component=vtctld' -o name | head -n1)" 15999 &
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector='planetscale.com/component=vtgate' -o name | head -n1)" 15306:3306 &
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector='planetscale.com/component=vtadmin' -o name | head -n1)" 14000:15000 14001:15001 &

sleep 2