#!/bin/sh

# Returns the execution RPC API URL based on the network
# Arguments:
#   $1: Network
get_execution_rpc_api_url_from_global_env() {
    network=$1
    execution_rpc_api_url="http://execution.${network}.dncore.dappnode:8545"
    echo "[INFO - entrypoint] Execution RPC API URL is: $execution_rpc_api_url" >&2
    echo "$execution_rpc_api_url"
}

# Returns the execution WebSocket URL based on the network
# Arguments:
#   $1: Network
get_execution_ws_url_from_global_env() {
    network=$1
    execution_ws_url="ws://execution.${network}.dncore.dappnode:8546"
    echo "[INFO - entrypoint] Execution WS URL is: $execution_ws_url" >&2
    echo "$execution_ws_url"
}

# Returns the beacon API URL based on the network
# Arguments:
#   $1: Network
get_beacon_api_url_from_global_env() {
    network=$1
    beacon_api_url="http://beacon-chain.${network}.dncore.dappnode:3500"
    echo "[INFO - entrypoint] Beacon API URL is: $beacon_api_url" >&2
    echo "$beacon_api_url"
}

# Returns the brain (from the Web3Signer package) URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_brain_api_url() {
    network=$1
    supported_networks=$2

    web3signer_domain=$(get_web3signer_domain "${network}" "${supported_networks}")

    brain_url="http://brain.${web3signer_domain}:3000"

    echo "[INFO - entrypoint] Web3Signer brain URL is: $brain_url" >&2

    echo "$brain_url"
}

_get_execution_alias() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    execution_dnp=$(get_value_from_global_env "EXECUTION_CLIENT" "$network")

    execution_alias=$(get_client_network_alias "$execution_dnp")

    if [ -z "$execution_alias" ]; then
        echo "[ERROR - entrypoint] Execution endpoint could not be determined" >&2
        exit 1
    fi

    echo "$execution_alias"
}

# common_tools.sh APPENDED HERE BY WORKFLOW
