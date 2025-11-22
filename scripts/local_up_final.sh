#!/bin/sh

# 1) Setup Port-forward
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector="planetscale.com/component=vtctld" -o name | head -n1)" 15000 15999 &
process_id1=$!
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector="planetscale.com/component=vtgate" -o name | head -n1)" 15306:3306 &
process_id2=$!
kubectl port-forward -n vitess --address localhost "$(kubectl get service -n vitess --selector="planetscale.com/component=vtadmin" -o name | head -n1)" 14000:15000 14001:15001 &
process_id3=$!

wait $process_id1
wait $process_id2
wait $process_id3

sleep 2

# 3) Set alias
alias vtctldclient="vtctldclient --server=localhost:15999"
alias mysql="mysql -h 127.0.0.1 -P 15306 -u user -p'password'"

# 3) Create Schema
vtctldclient ApplySchema --sql-file="$VITESS_OPERATOR/create_benchmark_schema.sql" benchmark
vtctldclient ApplyVSchema --vschema-file="$VITESS_OPERATOR/vschema_benchmark_initial.json" benchmark

# 4) Connect to your cluster
mysql