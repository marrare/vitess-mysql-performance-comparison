#!/usr/bin/env bash
set -e

# 1) Delete namespace vitess Or Delete only Inicial Cluster
echo "Deleting Vitess namespace..."
kubectl delete ns vitess --ignore-not-found
# kubectl delete -f ~/vitess/examples/operator/101_initial_cluster.yaml

# 2) Delete Minikube Cluster 
echo "Deleting Minikube cluster..."
minikube delete

# 3) Remove alias
echo "Removing mysql and vtctldclient aliases..."
unalias mysql && unalias vtctldclient

# 4) Docker Compose Down MySQL
echo "Bringing down MySQL Docker container..."
docker-compose -f ~/docker-compose.yaml -v