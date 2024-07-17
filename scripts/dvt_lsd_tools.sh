#!/bin/sh

# Export the EXECUTION_RPC_API_URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
export_execution_rpc_api_url() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    execution_dnp=$(get_value_from_global_env "EXECUTION_CLIENT" "$network")

    execution_alias=$(get_client_network_alias "$execution_dnp")

    if [ -z "$execution_alias" ]; then
        echo "[ERROR - entrypoint] Execution endpoint could not be determined"
        exit 1
    fi

    export EXECUTION_RPC_API_URL="http://${execution_alias}:8545"
}

# Export the BEACON_API_URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
export_beacon_api_url() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    consensus_dnp=$(get_value_from_global_env "CONSENSUS_CLIENT" "$network")

    consensus_alias=$(get_client_network_alias "$consensus_dnp")

    if [ -z "$consensus_alias" ]; then
        echo "[ERROR - entrypoint] Beacon endpoint could not be determined"
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

    export BEACON_API_URL="http://${beacon_service}.${consensus_alias}:${beacon_port}"
}

# Export the BRAIN_URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
export_brain_url() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    if [ "$network" = "mainnet" ]; then
        BRAIN_URL="http://brain.web3signer.dappnode:3000"
    else
        BRAIN_URL="http://brain.web3signer-${network}.dappnode:3000"
    fi

    export BRAIN_URL
}
