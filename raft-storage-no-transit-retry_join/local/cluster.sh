#!/bin/bash
# shellcheck disable=SC2005,SC2030,SC2031,SC2174
#
# This script helps manage Vault running in a multi-node cluster
# using the integrated storage (Raft) backend.
#
# Learn Guide: https://learn.hashicorp.com/vault/beta/raft-storage
#
# NOTES:
# - This script is intended only to be used in an educational capacity.
# - This script is not intended to manage a Vault in a production environment.
# - This script supports Linux and macOS
# - Linux support expects the 'ip' command instead of 'ifconfig' command

set -e

demo_home="$(pwd)"
script_name="$(basename "$0")"
os_name="$(uname -s | awk '{print tolower($0)}')"

if [ "$os_name" != "darwin" ] && [ "$os_name" != "linux" ]; then
  >&2 echo "Sorry, this script supports only Linux or macOS operating systems."
  exit 1
fi

function vault_to_network_address {
  local vault_node_name=$1

  case "$vault_node_name" in
    vault_1)
      echo "http://127.0.0.1:8200"
      ;;
    vault_2)
      echo "http://127.0.0.2:8200"
      ;;
    vault_3)
      echo "http://127.0.0.3:8200"
      ;;
  esac
}

# Create a helper function to address the first vault node
function vault_1 {
    (export VAULT_ADDR=http://127.0.0.1:8200 && export VAULT_TOKEN=$(cat root_token-vault_1) && vault "$@")
}

# Create a helper function to address the second vault node
function vault_2 {
    (export VAULT_ADDR=http://127.0.0.2:8200 && export VAULT_TOKEN=$(cat root_token-vault_2) && vault "$@")
}

# Create a helper function to address the third vault node
function vault_3 {
    (export VAULT_ADDR=http://127.0.0.3:8200 && export VAULT_TOKEN=$(cat root_token-vault_3) && vault "$@")
}

function stop_vault {
  local vault_node_name=$1

  service_count=$(pgrep -f "$(pwd)"/config-"$vault_node_name" | wc -l | tr -d '[:space:]')

  printf "\n%s" \
    "Found $service_count Vault service(s) matching that name"

  if [ "$service_count" != "0" ] ; then
    printf "\n%s" \
      "[$vault_node_name] stopping" \
      ""

    pkill -f "$(pwd)/config-$vault_node_name"
  fi
}

function stop {
  case "$1" in
    vault_1)
      stop_vault "vault_1"
      ;;
    vault_2)
      stop_vault "vault_2"
      ;;
    vault_3)
      stop_vault "vault_3"
      ;;
    all)
      for vault_node_name in vault_1 vault_2 vault_3 ; do
        stop_vault $vault_node_name
      done
      ;;
    *)
      printf "\n%s" \
        "Usage: $script_name stop [all|vault_1|vault_2|vault_3]" \
        ""
      ;;
    esac
}

function start_vault {
  local vault_node_name=$1

  local vault_network_address
  vault_network_address=$(vault_to_network_address "$vault_node_name")
  local vault_config_file=$demo_home/config-$vault_node_name.hcl
  local vault_log_file=$demo_home/$vault_node_name.log

  printf "\n%s" \
    "[$vault_node_name] starting Vault server @ $vault_network_address" \
    ""

  vault server -log-level=trace -config "$vault_config_file" > "$vault_log_file" 2>&1 &
}

function start {
  case "$1" in
    vault_1)
      start_vault "vault_1"
      ;;
    vault_2)
      start_vault "vault_2"
      ;;
    vault_3)
      start_vault "vault_3"
      ;;
    all)
      for vault_node_name in vault_1 vault_2 vault_3 ; do
        start_vault $vault_node_name
      done
      ;;
    *)
      printf "\n%s" \
        "Usage: $script_name stop [all|vault_1|vault_2|vault_3]" \
        ""
      ;;
    esac
}

function loopback_exists_at_address {
  case "$os_name" in
  darwin)
    echo "$(ifconfig lo0 | grep "$1" || true)" | tr -d '[:space:]'
    ;;
  linux)
    echo "$(ip addr show dev lo | grep "$1" || true)" | tr -d '[:space:]'
    echo "$(ip addr show dev lo | grep "$1" || true)" | tr -d '[:space:]'
    echo "$(ip addr show dev lo | grep "$1" || true)" | tr -d '[:space:]'
    ;;
  esac
}

function clean {

  printf "\n%s" \
    "Cleaning up the HA cluster. Removing:" \
    " - local loopback address for [vault_1], [vault_2], and [vault_3]" \
    " - configuration files" \
    " - raft storage directory" \
    " - log files" \
    " - unseal / recovery keys" \
    ""

  for loopback_address in "127.0.0.2" "127.0.0.3" ; do
    loopback_exists=$(loopback_exists_at_address $loopback_address)
    if [[ $loopback_exists != "" ]] ; then
      printf "\n%s" \
        "Removing local loopback address: $loopback_address (sudo required)" \
        ""
        case "$os_name" in
        darwin)
          sudo ifconfig lo0 -alias $loopback_address
          ;;
        linux)
          sudo ip addr del "$loopback_address"/8 dev lo
          ;;
        esac
    fi
  done

  for config_file in $demo_home/config-vault_1.hcl $demo_home/config-vault_2.hcl $demo_home/config-vault_3.hcl ; do
    if [[ -f "$config_file" ]] ; then
      printf "\n%s" \
        "Removing configuration file $config_file"

      rm "$config_file"
      printf "\n"
    fi
  done

  for raft_storage in $demo_home/raft-vault_1 $demo_home/raft-vault_2 $demo_home/raft-vault_3 ; do
    if [[ -d "$raft_storage" ]] ; then
    printf "\n%s" \
        "Removing raft storage file $raft_storage"

      rm -rf "$raft_storage"
    fi
  done

  for key_file in $demo_home/unseal_key-vault_1 ; do
    if [[ -f "$key_file" ]] ; then
      printf "\n%s" \
        "Removing key $key_file"

      rm "$key_file"
    fi
  done

  for token_file in $demo_home/root_token-vault_1 ; do
    if [[ -f "$token_file" ]] ; then
      printf "\n%s" \
        "Removing key $token_file"

      rm "$token_file"
    fi
  done

  for vault_log in $demo_home/vault_1.log $demo_home/vault_2.log $demo_home/vault_3.log ; do
    if [[ -f "$vault_log" ]] ; then
      printf "\n%s" \
        "Removing log file $vault_log"

      rm "$vault_log"
    fi
  done


  if [[ -f "$demo_home/demo.snapshot" ]] ; then
    printf "\n%s" \
      "Removing demo.snapshot"

    rm demo.snapshot
  fi

  # to successfully demo again later, previous VAULT_TOKEN cannot be present
  unset VAULT_TOKEN

  printf "\n%s" \
    "Clean complete" \
    ""
}

function status {
  service_count=$(pgrep -f "$(pwd)"/config | wc -l | tr -d '[:space:]')

  printf "\n%s" \
    "Found $service_count Vault services" \
    ""

  if [[ "$service_count" != 3 ]] ; then
    printf "\n%s" \
    "Unable to find all Vault services" \
    ""
  fi

  printf "\n%s" \
    "[vault_1] status" \
    ""
  vault_1 status || true

  printf "\n%s" \
    "[vault_2] status" \
    ""
  vault_2 status || true

  printf "\n%s" \
    "[vault_3] status" \
    ""
  vault_3 status || true

  sleep 2
}

function create_network {

  case "$os_name" in
    darwin)
      printf "\n%s" \
      "[vault_2] Enabling local loopback on 127.0.0.2 (requires sudo)" \
      ""

      sudo ifconfig lo0 alias 127.0.0.2

      printf "\n%s" \
        "[vault_3] Enabling local loopback on 127.0.0.3 (requires sudo)" \
        ""

      sudo ifconfig lo0 alias 127.0.0.3

      ;;
    linux)
      printf "\n%s" \
      "[vault_2] Enabling local loopback on 127.0.0.2 (requires sudo)" \
      ""

      sudo ip addr add 127.0.0.2/8 dev lo label lo:0

      printf "\n%s" \
        "[vault_3] Enabling local loopback on 127.0.0.3 (requires sudo)" \
        ""

      sudo ip addr add 127.0.0.3/8 dev lo label lo:1

      ;;
  esac

}

function create_config {
  printf "\n%s" \
    "[vault_1] Creating configuration" \
    "  - creating $demo_home/config-vault_1.hcl"

  rm -f config-vault_1.hcl
  rm -rf "$demo_home"/raft-vault_1
  mkdir -pm 0755 "$demo_home"/raft-vault_1

  tee "$demo_home"/config-vault_1.hcl 1> /dev/null <<EOF
storage "raft" {
  path    = "$demo_home/raft-vault_1/"
  node_id = "vault_1"
  #retry_join {
  #  leader_api_addr = "http://127.0.0.2:8200"
  #}
  #retry_join {
  #  leader_api_addr = "http://127.0.0.3:8200"
  #}
}

listener "tcp" {
   address = "127.0.0.1:8200"
   cluster_address = "127.0.0.1:8201"
   tls_disable = true
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
ui = true
disable_mlock = true
EOF

  printf "\n%s" \
    "[vault_2] Creating configuration" \
    "  - creating $demo_home/config-vault_2.hcl" \
    "  - creating $demo_home/raft-vault_2"

  rm -f config-vault_2.hcl
  rm -rf "$demo_home"/raft-vault_2
  mkdir -pm 0755 "$demo_home"/raft-vault_2

  tee "$demo_home"/config-vault_2.hcl 1> /dev/null <<EOF
storage "raft" {
  path    = "$demo_home/raft-vault_2/"
  node_id = "vault_2"
  #retry_join {
  #  leader_api_addr = "http://127.0.0.1:8200"
  #}
  #retry_join {
  #  leader_api_addr = "http://127.0.0.3:8200"
  #}
}

listener "tcp" {
   address = "127.0.0.2:8200"
   cluster_address = "127.0.0.2:8201"
   tls_disable = true
}

ui = true
disable_mlock = true
api_addr = "http://127.0.0.2:8200"
cluster_addr = "http://127.0.0.2:8201"
EOF

  printf "\n%s" \
    "[vault_3] Creating configuration" \
    "  - creating $demo_home/config-vault_3.hcl" \
    "  - creating $demo_home/raft-vault_3"

  rm -f config-vault_3.hcl
  rm -rf "$demo_home"/raft-vault_3
  mkdir -pm 0755 "$demo_home"/raft-vault_3

  tee "$demo_home"/config-vault_3.hcl 1> /dev/null <<EOF
storage "raft" {
  path    = "$demo_home/raft-vault_3/"
  node_id = "vault_3"
  #retry_join {
  #  leader_api_addr = "http://127.0.0.1:8200"
  #}
  #retry_join {
  #  leader_api_addr = "http://127.0.0.2:8200"
  #}
}

listener "tcp" {
   address = "127.0.0.3:8200"
   cluster_address = "127.0.0.3:8201"
   tls_disable = true
}

ui = true
disable_mlock = true
api_addr = "http://127.0.0.3:8200"
cluster_addr = "http://127.0.0.3:8201"
EOF

  printf "\n"
}

function setup_vault_1 {
  start_vault "vault_1"
  sleep 5

  printf "\n%s" \
    "[vault_1] initializing and capturing the unseal key and root token" \
    ""
  sleep 2 # Added for human readability

  INIT_RESPONSE=$(vault_1 operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key-vault_1
  echo "$VAULT_TOKEN" > root_token-vault_1

  printf "\n%s" \
    "[vault_1] Unseal key: $UNSEAL_KEY" \
    "[vault_1] Root token: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "[vault_1] unsealing and logging in" \
    ""
  sleep 2 # Added for human readability

  vault_1 operator unseal "$UNSEAL_KEY"
  vault_1 login "$VAULT_TOKEN"
}

function setup_vault_2 {
  start_vault "vault_2"
  sleep 5

  printf "\n%s" \
    "[vault_2] initializing and capturing the unseal key and root token" \
    ""
  sleep 2 # Added for human readability

  INIT_RESPONSE=$(vault_2 operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key-vault_2
  echo "$VAULT_TOKEN" > root_token-vault_2

  printf "\n%s" \
    "[vault_2] Unseal key: $UNSEAL_KEY" \
    "[vault_2] Root token: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "[vault_2] unsealing and logging in" \
    ""
  sleep 2 # Added for human readability

  vault_2 operator unseal "$UNSEAL_KEY"
  vault_2 login "$VAULT_TOKEN"
}

function setup_vault_3 {
  start_vault "vault_3"
  sleep 5

  printf "\n%s" \
    "[vault_3] initializing and capturing the unseal key and root token" \
    ""
  sleep 2 # Added for human readability

  INIT_RESPONSE=$(vault_3 operator init -format=json -key-shares 1 -key-threshold 1)

  UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key-vault_3
  echo "$VAULT_TOKEN" > root_token-vault_3

  printf "\n%s" \
    "[vault_3] Unseal key: $UNSEAL_KEY" \
    "[vault_3] Root token: $VAULT_TOKEN" \
    ""

  printf "\n%s" \
    "[vault_3] unsealing and logging in" \
    ""
  sleep 2 # Added for human readability

  vault_3 operator unseal "$UNSEAL_KEY"
  vault_3 login "$VAULT_TOKEN"
}

function unseal_vault {
  local vault_node_name=$1

  printf "\n%s" \
    "$vault_node_name unsealing with unseal key from $vault_node_name" \
    ""
  sleep 2 # Added for human readability

  UNSEAL_KEY=$(cat "$demo_home"/unseal_key-$vault_node_name)
  $vault_node_name operator unseal "$UNSEAL_KEY"
}

function unseal {
  case "$1" in
    vault_1)
      unseal_vault "vault_1"
      ;;
    vault_2)
      unseal_vault "vault_2"
      ;;
    vault_3)
      unseal_vault "vault_3"
      ;;
    all)
      for vault_node_name in vault_1 vault_2 vault_3 ; do
        unseal_vault $vault_node_name
      done
      ;;
    *)
      printf "\n%s" \
        "Usage: $script_name unseal [all|vault_1|vault_2|vault_3]" \
        ""
      ;;
    esac
}

function create {
  case "$1" in
    network)
      shift ;
      create_network "$@"
      ;;
    config)
      shift ;
      create_config "$@"
      ;;
    *)
      printf "\n%s" \
      "Creates resources for the cluster." \
      "Usage: $script_name create [network|config]" \
      ""
      ;;
  esac
}

function setup {
  case "$1" in
    vault_1)
      setup_vault_1
      ;;
    vault_2)
      setup_vault_2
      ;;
    vault_3)
      setup_vault_3
      ;;
    all)
      for vault_setup_function in setup_vault_1 setup_vault_2 setup_vault_3 ; do
        $vault_setup_function
      done
      ;;
    *)
      printf "\n%s" \
      "Sets up resources for the cluster" \
      "Usage: $script_name setup [all|vault_1|vault_2|vault_3]" \
      ""
      ;;
  esac
}

case "$1" in
  create)
    shift ;
    create "$@"
    ;;
  setup)
    shift ;
    setup "$@"
    ;;
  unseal)
    shift ;
    unseal "$@"
    ;;
  vault_1)
    shift ;
    vault_1 "$@"
    ;;
  vault_2)
    shift ;
    vault_2 "$@"
    ;;
  vault_3)
    shift ;
    vault_3 "$@"
    ;;
  status)
    status
    ;;
  start)
    shift ;
    start "$@"
    ;;
  stop)
    shift ;
    stop "$@"
    ;;
  clean)
    stop all
    clean
    ;;
  *)
    printf "\n%s" \
      "This script helps manages a Vault HA cluster with raft storage." \
      "View the README.md the complete guide at https://learn.hashicorp.com/vault/beta/raft-storage" \
      "" \
      "Usage: $script_name [create|setup|unseal|status|stop|clean|vault_1|vault_2|vault_3]" \
      ""
    ;;
esac
