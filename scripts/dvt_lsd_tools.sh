#!/bin/sh

# TODO: Remove this function in favour of http://execution.${NETWORK}.dncore.dappnode:8545
# Returns the execution RPC API URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_execution_rpc_api_url_from_global_env() {
    network=$1
    supported_networks=$2

    execution_alias=$(_get_execution_alias "$network" "$supported_networks")

    execution_rpc_api_url="http://${execution_alias}:8545"

    echo "[INFO - entrypoint] Execution RPC API URL is: $execution_rpc_api_url" >&2

    echo "$execution_rpc_api_url"
}

# TODO: Remove this function in favour of ws://execution.${NETWORK}.dncore.dappnode:8546 (ONLY when all clients expose WS on 8546)
get_execution_ws_url_from_global_env() {
    network=$1
    supported_networks=$2
    port=8546

    execution_dnp=$(get_value_from_global_env "EXECUTION_CLIENT" "$network")

    # TODO: Set all execution clients WS port to 8546
    if [ "$execution_dnp" = "holesky-erigon.dnp.dappnode.eth" ] || [ "$execution_dnp" = "nethermind.public.dappnode.eth" ] || [ "$execution_dnp" = "nethermind-xdai.dnp.dappnode.eth" ]; then
        port=8545
    fi

    execution_alias=$(_get_execution_alias "$network" "$supported_networks")

    execution_ws_url="ws://${execution_alias}:${port}"

    echo "[INFO - entrypoint] Execution WS URL is: $execution_ws_url" >&2

    echo "$execution_ws_url"
}

# TODO: Remove this function in favour of http://beacon-chain.holesky.dncore.dappnode:3500 (ONLY when nimbus client has been published with 2 services)
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
