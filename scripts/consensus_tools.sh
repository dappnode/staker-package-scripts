#!/bin/sh

MEVBOOST_SUPPORTED_NETWORKS="mainnet holesky"

# Returns the engine URL based on the execution client selected in the Stakers tab
#
# Arguments:
#   $1: Network
#   $2: Supported networks
get_engine_api_url() {
    network=$1
    supported_networks=$2

    execution_dnp=$(_get_execution_dnp "$network" "$supported_networks")
    execution_alias=$(get_client_network_alias "$execution_dnp")

    echo "http://${execution_alias}:8551"
}

# Returns the execution RPC API URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_execution_rpc_api_url() {
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
get_beacon_api_url() {
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

get_signer_api_url() {
    network=$1
    supported_networks=$2

    web3signer_alias=$(_get_web3signer_alias "${network}" "${supported_networks}")

    signer_url="http://web3signer.${web3signer_alias}:9000"

    echo "[INFO - entrypoint] Web3Signer signer URL is: $signer_url" >&2

    echo "$signer_url"
}

# Set the checkpoint sync URL to the EXTRA_OPTS environment variable
# The beacon node will use this URL to sync the checkpoints
#
# Arguments:
#   $1: Checkpoint flag
#   $2: Checkpoint URL
#
# shellcheck disable=SC2120 # This script is sourced
get_checkpoint_sync_url() {
    checkpoint_flag="$1"
    checkpoint_url="$2"

    if [ -n "$checkpoint_url" ]; then
        echo "[INFO - entrypoint] Checkpoint sync URL is set to $checkpoint_url" >&2
        echo "${checkpoint_flag}=${checkpoint_url}"
    else
        echo "[WARN - entrypoint] Checkpoint sync URL is not set" >&2
    fi
}

# Set the MEV Boost flag and URL to the EXTRA_OPTS environment variable
# The beacon node will use this flag and URL to enable MEV Boost
#
# Arguments:
#   $1: Network --> e.g. "mainnet"
#   $2: MEV Boost flag --> e.g. "--builder"
#   $3: Skip MEV Boost URL flag --> e.g. "true" to skip setting the URL
#
# shellcheck disable=SC2120 # This script is sourced
get_mevboost_flag() {
    network=$1
    mevboost_flag=$2
    skip_mevboost_url=$3

    mevboost_enabled=$(get_value_from_global_env "MEVBOOST" "$network")

    # shellcheck disable=SC2154
    if [ "${mevboost_enabled}" = "true" ]; then
        echo "[INFO - entrypoint] MEV Boost is enabled" >&2
        mevboost_url=$(_get_mevboost_url "$network")

        if _is_mevboost_available; then
            if [ "${skip_mevboost_url}" = "true" ]; then
                mevboost_flag_to_add="${mevboost_flag}"
            else
                mevboost_flag_to_add="${mevboost_flag}=${mevboost_url}"
            fi

            echo "[INFO - entrypoint] MEV Boost flag is set to $mevboost_flag_to_add" >&2
            echo "${mevboost_flag_to_add}"
        fi
    else
        echo "[INFO - entrypoint] MEV Boost is disabled" >&2
    fi
}

# Set graffiti to the first 32 characters if it is set
get_valid_graffiti() {
    graffiti="$1"

    # Save current locale settings
    oLang="$LANG" oLcAll="$LC_ALL"

    # Set locale to C for consistent behavior in string operations
    LANG=C LC_ALL=C

    if [ -z "$graffiti" ]; then
        valid_graffiti=""
    else
        # Truncate graffiti to 32 characters if it is set
        valid_graffiti=$(echo "$graffiti" | cut -c 1-32)
    fi

    echo "[INFO] Using graffiti: $valid_graffiti" >&2

    echo "$valid_graffiti"

    # Restore locale settings
    LANG="$oLang" LC_ALL="$oLcAll"
}

get_valid_fee_recipient() {
    fee_recipient="$1"

    if echo "$fee_recipient" | grep -Eq '^0x[a-fA-F0-9]{40}$'; then
        echo "[INFO - entrypoint] Fee recipient address (${fee_recipient}) is valid" >&2
    else
        echo "[WARN - entrypoint] Fee recipient address is invalid. It should be an Ethereum address" >&2
        echo "[WARN - entrypoint] Setting the fee recipient address to the burn address" >&2
        fee_recipient="0x0000000000000000000000000000000000000000"
    fi

    echo "$fee_recipient"
}

# INTERNAL FUNCTIONS (Not meant to be called directly)

# Set the DNP name of the execution client selected in the Stakers tab to the execution_dnp environment variable
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_get_execution_dnp() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"
    execution_dnp=$(get_value_from_global_env "EXECUTION_CLIENT" "$network")

    if [ -z "$execution_dnp" ]; then
        echo "[ERROR - entrypoint] Execution client is not set for $network" >&2
        exit 1
    fi

    # Return the execution DNP name via stdout
    echo "$execution_dnp"
}

# Set the MEV Boost URL based on the network
#
# Arguments:
#   $1: Network
_get_mevboost_url() {
    network=$1
    _verify_network_support "$network" "$MEVBOOST_SUPPORTED_NETWORKS"

    # If network is mainnet and MEV-Boost is enabled, set the MEV-Boost URL
    if [ "${network}" = "mainnet" ]; then
        mevboost_url="http://mev-boost.dappnode:18550"
    else
        mevboost_url="http://mev-boost-${network}.dappnode:18550"
    fi

    echo "[INFO - entrypoint] MEV Boost URL is: $mevboost_url" >&2

    echo "$mevboost_url"
}

# Verify if the MEV Boost URL is reachable
# In case curl is not installed, MEV Boost is assumed to be available
_is_mevboost_available() {
    if [ -z "${MEVBOOST_URL:-}" ]; then
        echo "[ERROR - entrypoint] MEV Boost URL is not set" >&2
        return 1
    fi

    _verify_network_support "$network" "$supported_networks"

    if [ "$network" = "mainnet" ]; then
        brain_url="http://brain.web3signer.dappnode:3000"
    else
        brain_url="http://brain.web3signer-${network}.dappnode:3000"
    fi
}

_get_web3signer_alias() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    if [ "$network" = "mainnet" ]; then
        brain_url="http://brain.web3signer.dappnode:3000"
    else
        brain_url="http://brain.web3signer-${network}.dappnode:3000"
    fi
}

# common_tools.sh APPENDED HERE BY WORKFLOW
