#!/usr/bin/env bash

export $(grep -v '^#' ../.env | xargs)

# Helper: check required commands
check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERRO: '$1' não está instalado ou não está no PATH. Instale-o e tente novamente."
    exit 1
  fi
}

check_cmd kubectl
check_cmd vtctldclient

case "$ENVIRONMENT" in
  local)
    check_cmd minikube

    echo "***** INICIANDO AMBIENTE LOCAL COM MINIKUBE ****"
    minikube delete
    minikube start --kubernetes-version=v1.32.2 --cpus=4 --memory=16g --disk-size=32g
    minikube addons disable metrics-server #Necessário para rodar kube-prometheus
    ;;
  aws)
    check_cmd terraform
    check_cmd aws

    echo "***** INICIANDO AMBIENTE AWS COM EC2 E EKS *****"
    cd ../
    terraform init
    terraform plan
    terraform apply
    aws eks update-kubeconfig --region us-east-1 --name research-cluster --profile tcc
    cd -
    ;;
esac

echo "***** CONFIGURANDO VITESS NO CLUSTER KUBERNETES *****"
kubectl create namespace vitess
kubectl apply -f ../dependencies/vitess/operator.yaml -n vitess
kubectl apply -f ../dependencies/vitess/101_initial_cluster.yaml -n vitess

echo "***** AGUARDANDO VITESS INICIAR *****"
kubectl wait --for=condition=available deployment vitess-operator -n vitess --timeout=300s

if [[ "$ENVIRONMENT" == "local" ]]; then
  echo "***** INICIANDO MYSQL LOCAL COM DOCKER *****"
  docker-compose -f ../dependencies/mysql/docker-compose.yml up -d --force-recreate
else 
  echo
  echo "***** MYSQL DEVE SER CONFIGURADO MANUALMENTE *****"
  echo "ssh -i keys/research-cluster-ssh-key.pem ec2-user@IP_PUBLICO_DA_INSTANCIA"
  echo "sudo yum install mysql-server -y"
  echo "sudo systemctl start mysqld"
  echo "sudo systemctl enable mysqld"
  echo "sudo mysql_secure_installation"
  echo "sudo nano /etc/mysql/conf.d"
  echo "# port 3654"
  echo "# bindaddress 0.0.0.0"
  echo 
fi

echo "***** CONFIGURANDO PROMETHEUS E GRAFANA *****"
kubectl create -f ../dependencies/prometheus/setup
kubectl apply -f ../dependencies/prometheus

echo "***** AGUARDANDO PROMETHEUS E GRAFANA INICIAR *****"
kubectl wait --for=condition=available deployment blackbox-exporter -n monitoring --timeout=300s
kubectl wait --for=condition=available deployment grafana -n monitoring --timeout=300s
kubectl wait --for=condition=available deployment kube-state-metrics -n monitoring --timeout=300s
kubectl wait --for=condition=available deployment prometheus-adapter -n monitoring --timeout=300s
kubectl wait --for=condition=available deployment prometheus-operator -n monitoring --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=k8s -n monitoring --timeout=300s

source pf.sh

# Aliases: only useful if the script is sourced. Otherwise print instructions.
is_sourced() {
  # Returns true if script is being sourced
  (return 0 2>/dev/null) && [ "${BASH_SOURCE[0]}" != "$0" ]
}

if is_sourced; then
  echo "***** DEFININDO ALIASES PARA VTCTLDCLIENT E MYSQL *****"
  alias vtctldclient="vtctldclient --server=localhost:15999"
  alias mysqlv="mysql -h ${VITESS_HOST} -P ${VITESS_PORT} -u ${VITESS_USER} -p'${VITESS_PASSWORD}'"
  alias mysql="mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u root -p'$MYSQL_ROOT_PASSWORD'"
else
  echo
  echo "Nota: para definir aliases no seu shell atual, rode:"
  echo "  source ./infra.sh"
  echo "Ou adicione estas linhas ao seu ~/.bashrc / ~/.bash_profile:"
  echo "  alias vtctldclient='vtctldclient --server=localhost:15999'"
  echo "  alias mysqlv=\"mysql -h 127.0.0.1 -P 15306 -u user -p'password'\""
  echo
fi

# Apply initial schema and vschema
echo "***** APLICANDO SCHEMA E VSCHEMA INICIAIS *****"
vtctldclient ApplySchema --sql-file="../dependencies/vitess/create_schema.sql" benchmark || echo "Falha ao aplicar schema"
vtctldclient ApplyVSchema --vschema-file="../dependencies/vitess/vschema_sharded.json" benchmark || echo "Falha ao aplicar vschema"

echo
echo "Para conectar ao cluster com mysql (via port forward):"
echo "  mysqlv - para conectar ao Vitess"
echo "  mysql  - para conectar ao MySQL"
echo