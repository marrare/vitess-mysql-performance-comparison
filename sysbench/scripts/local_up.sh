#!/usr/bin/env bash
set -e

# 1) start a Minikube engine and create namespace vitess
minikube start --kubernetes-version=v1.32.2 --cpus=4 --memory=11000 --disk-size=32g

kubectl create namespace vitess
kubectl config set-context --current --namespace=vitess

# 2) Install the Vitess Operator
# git clone https://github.com/vitessio/vitess
# cd vitess/examples/operator
# git checkout release-22.0

# Realizado um fork da release-22.0 e feito alterações do "namespace: example" para "namespace: vitess" em "vitess/examples/operator/operator.yaml"
kubectl apply -f ~/vitess/examples/operator/operator.yaml

# 3) Bring up an initial cluster
# Realizado um fork da release-22.0 e feito alterações do "keyspace: commerce" para "keyspace: benchmark" em "vitess/examples/operator/101_initial_cluster.yaml"
kubectl apply -f ~/vitess/examples/operator/101_initial_cluster.yaml

# 4) Verify cluster
sleep 5; kubectl get pods -n vitess

# 5) Docker Compose Up MySQL
docker compose -f ~/BENCHMARK_LOCAL/configs/docker-compose.yml up -d;
docker compose -f ~/docker-compose.yml ps;