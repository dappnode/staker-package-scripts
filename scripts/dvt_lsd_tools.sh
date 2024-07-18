#!/bin/sh
# Returns the execution RPC API URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_execution_rpc_api_url_from_global_env() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    execution_dnp=$(get_value_from_global_env "EXECUTION_CLIENT" "$network")

    execution_alias=$(get_client_network_alias "$execution_dnp")

    if [ -z "$execution_alias" ]; then
        echo "[ERROR - entrypoint] Execution endpoint could not be determined" >&2
        exit 1
    fi

    execution_rpc_api_url="http://${execution_alias}:8545"

    echo "[INFO - entrypoint] Execution RPC API URL is: $execution_rpc_api_url" >&2

    echo "$execution_rpc_api_url"
}

# Returns the beacon API URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_beacon_api_url_from_global_env() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    consensus_dnp=$(get_value_from_global_env "CONSENSUS_CLIENT" "$network")

    consensus_alias=$(get_client_network_alias "$consensus_dnp")

    if [ -z "$consensus_alias" ]; then
        echo "[ERROR - entrypoint] Beacon endpoint could not be determined" >&2
        exit 1
    fi

    # If consensus client is nimbus, the beacon service is beacon-validator
    if echo "$consensus_dnp" | grep -q "nimbus"; then
        beacon_service="beacon-validator"
        beacon_port="4500"
    else
        beacon_service="beacon-chain"
        beacon_port="3500"
    fi

    beacon_api_url="http://${beacon_service}.${consensus_alias}:${beacon_port}"

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

    web3signer_alias=$(_get_web3signer_alias "${network}" "${supported_networks}")

    brain_url="http://brain.${web3signer_alias}:3000"

    echo "[INFO - entrypoint] Web3Signer brain URL is: $brain_url" >&2

    echo "$brain_url"
}

# common_tools.sh APPENDED HERE BY WORKFLOW
