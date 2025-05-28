#!/bin/sh

MEVBOOST_SUPPORTED_NETWORKS="mainnet holesky hoodi"

# TODO: Remove this function once all clients have migrated to staker network
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

# Returns the beacon API URL based on the network and supported networks
#
# Arguments:
#   $1: Network
#   $2: Supported networks (space-separated list)
get_beacon_api_url() {
    network=$1
    supported_networks=$2
    consensus_client=$3 # Example: lodestar

    _verify_network_support "$network" "$supported_networks"

    if [ -z "$consensus_client" ]; then
        echo "[ERROR - entrypoint] Client is not set. It must be set to one of: lodestar, nimbus, prysm, teku or lighthouse" >&2
        exit 1
    fi

    if [ "$consensus_client" = "nimbus" ]; then
        beacon_service="beacon-validator"
        beacon_port="4500"
    else
        beacon_service="beacon-chain"
        beacon_port="3500"
    fi

    # TODO: What if a public package is published for a consensus client?
    if [ "$network" = "mainnet" ]; then
        consensus_alias="${consensus_client}.dappnode"
    else
        consensus_alias="${consensus_client}-${network}.dappnode"
    fi

    beacon_api_url="http://${beacon_service}.${consensus_alias}:${beacon_port}"

    echo "[INFO - entrypoint] Beacon API URL is: $beacon_api_url" >&2

    echo "$beacon_api_url"

}

get_signer_api_url() {
    network=$1
    supported_networks=$2

    web3signer_domain=$(get_web3signer_domain "${network}" "${supported_networks}")

    signer_url="http://web3signer.${web3signer_domain}:9000"

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
get_checkpoint_sync_flag() {
    checkpoint_flag_key="$1"
    checkpoint_url="$2"

    if [ -n "$checkpoint_url" ]; then
        echo "[INFO - entrypoint] Checkpoint sync URL is set to $checkpoint_url" >&2
        echo "${checkpoint_flag_key}=${checkpoint_url}"
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

        if _is_mevboost_available "${mevboost_url}"; then
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

    echo "[INFO - entrypoint] Using graffiti: $valid_graffiti" >&2

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
    mevboost_url=$1

    if [ -z "${mevboost_url:-}" ]; then
        echo "[ERROR - entrypoint] MEV Boost URL is not set" >&2
        return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "[WARN - entrypoint] curl is not installed. Skipping MEV Boost availability check" >&2
        return 0
    fi

    if curl --retry 5 --retry-delay 5 --retry-all-errors "${mevboost_url}" >/dev/null 2>&1; then
        echo "[INFO - entrypoint] MEV Boost is available" >&2
        return 0
    else
        echo "[ERROR - entrypoint] MEV Boost is enabled but the package at ${mevboost_url} is not reachable. Disabling MEV Boost..." >&2
        return 1
    fi
}

# common_tools.sh APPENDED HERE BY WORKFLOW
