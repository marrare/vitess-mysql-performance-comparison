#!/usr/bin/env bash

export $(grep -v '^#' ../.env | xargs)

case "$ENVIRONMENT" in
  local)
    echo "***** DELETANDO MINIKUBE CLUSTER ****"
    minikube delete
    docker-compose -f ../dependencies/mysql/docker-compose.yml down -v
    ;;
  aws)
    echo "***** INICIANDO AMBIENTE AWS COM EC2 E EKS *****"
    cd ../
    terraform destroy -auto-approve
    kubectl config delete-cluster research-cluster
    cd -
    ;;
esac

# 3) Remove alias
echo "***** REMOVING ALIASES FOR VTCTLDCLIENT AND MYSQL *****"
unalias vtctldclient && unalias mysqlv && unalias mysql

source pf_kill.sh