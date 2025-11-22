#!/usr/bin/env bash
set -e

# 1) Delete namespace vitess Or Delete only Inicial Cluster
kubectl delete ns vitess --ignore-not-found
# kubectl delete -f ~/vitess/examples/operator/101_initial_cluster.yaml

# 2) Delete Minikube Cluster 
minikube delete

# 3) Remove alias
unalias mysql && unalias vtctldclient

# 4) Docker Compose Down MySQL
docker compose -f ~/docker-compose.yaml -v