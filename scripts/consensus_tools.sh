#!/bin/sh

MEVBOOST_SUPPORTED_NETWORKS="mainnet holesky"

# Set network-specific configuration
#
# Arguments:
#   $1: Supported networks
#   $2: Network-specific flags (can be unset)
set_consensus_config_by_network() {
    supported_networks=$1
    network_specific_flags=$2 # In case specific flags need to be set for a network

    echo "[INFO - entrypoint] Initializing $NETWORK specific config for client"

    _set_engine_url "$supported_networks"

    if [ -n "$network_specific_flags" ]; then
        export EXTRA_OPTS="${network_specific_flags} ${EXTRA_OPTS:-}"
    fi
}

# Set the checkpoint sync URL to the EXTRA_OPTS environment variable
# The beacon node will use this URL to sync the checkpoints
#
# Arguments:
#   $1: Checkpoint flag
#   $2: Checkpoint URL
#
# shellcheck disable=SC2120 # This script is sourced
set_checkpointsync_url() {
    checkpoint_flag="$1"
    checkpoint_url="$2"

    if [ -n "$checkpoint_url" ]; then
        echo "[INFO - entrypoint] Checkpoint sync URL is set to $checkpoint_url"
        export EXTRA_OPTS="${checkpoint_flag}=${checkpoint_url} ${EXTRA_OPTS:-}"
    else
        echo "[WARN - entrypoint] Checkpoint sync URL is not set"
    fi
}

# Set the MEV Boost flag and URL to the EXTRA_OPTS environment variable
# The beacon node will use this flag and URL to enable MEV Boost
#
# Arguments:
#   $1: MEV Boost flag
#   $2: Skip MEV Boost URL flag
#
# shellcheck disable=SC2120 # This script is sourced
set_mevboost_flag() {
    mevboost_flag="$1"
    skip_mevboost_url="$2"

    uppercase_network=$(_to_upper_case "$NETWORK")
    mevboost_enabled_var="_DAPPNODE_GLOBAL_MEVBOOST_${uppercase_network}"

    # Using eval to check and assign the variable, ensuring it's not unbound
    eval "mevboost_enabled=\${${mevboost_enabled_var}:-false}"

    # shellcheck disable=SC2154
    if [ "${mevboost_enabled}" = "true" ]; then

        echo "[INFO - entrypoint] MEV Boost is enabled"
        _set_mevboost_url

        if _is_mevboost_available; then

            if [ "${skip_mevboost_url}" = "true" ]; then
                export EXTRA_OPTS="${mevboost_flag} ${EXTRA_OPTS:-}"
            else
                export EXTRA_OPTS="${mevboost_flag}=${MEVBOOST_URL} ${EXTRA_OPTS:-}"
            fi
        fi
    else
        echo "[INFO - entrypoint] MEV Boost is disabled"
    fi
}

# Set graffiti to the first 32 characters if it is set
format_graffiti() {
    # Save current locale settings
    oLang="$LANG" oLcAll="$LC_ALL"

    # Set locale to C for consistent behavior in string operations
    LANG=C LC_ALL=C

    if [ -z "$GRAFFITI" ]; then
        valid_graffiti=""
    else
        # Truncate GRAFFITI to 32 characters if it is set
        valid_graffiti=$(echo "$GRAFFITI" | cut -c 1-32)
    fi

    echo "[INFO] Using graffiti: $valid_graffiti"

    export GRAFFITI="$valid_graffiti"

    # Restore locale settings
    LANG="$oLang" LC_ALL="$oLcAll"
}

# INTERNAL FUNCTIONS (Not meant to be called directly)

_to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Set the engine URL based on the execution client selected in the Stakers tab
#
# Arguments:
#   $1: Supported networks
_set_engine_url() {
    supported_networks=$1

    _set_execution_dnp "$supported_networks"

    case "$EXECUTION_DNP" in
    *".public."*)
        # nethermind.public.dappnode.eth -> nethermind.public
        execution_subdomain=$(echo "$EXECUTION_DNP" | cut -d'.' -f1-2)
        ;;
    *)
        # geth.dnp.dappnode.eth -> geth
        execution_subdomain=$(echo "$EXECUTION_DNP" | cut -d'.' -f1)
        ;;
    esac

    export HTTP_ENGINE="http://${execution_subdomain}.dappnode:8551"
}

# Set the DNP name of the execution client selected in the Stakers tab to the EXECUTION_DNP environment variable
#
# Arguments:
#   $1: Supported networks
_set_execution_dnp() {
    supported_networks=$1

    _verify_network_support "$supported_networks"

    uppercase_network=$(_to_upper_case "$NETWORK")
    execution_dnp_var="_DAPPNODE_GLOBAL_EXECUTION_CLIENT_${uppercase_network}"
    eval "EXECUTION_DNP=\${$execution_dnp_var}"

    if [ -z "$EXECUTION_DNP" ]; then
        echo "[ERROR - entrypoint] Execution client is not set for $NETWORK"
        exit 1
    fi

    export EXECUTION_DNP
}

# Set the MEV Boost URL based on the network
_set_mevboost_url() {
    _verify_network_support "$MEVBOOST_SUPPORTED_NETWORKS"

    # If network is mainnet and MEV-Boost is enabled, set the MEV-Boost URL
    if [ "${NETWORK}" = "mainnet" ]; then
        export MEVBOOST_URL="http://mev-boost.dappnode:18550"
    else
        export MEVBOOST_URL="http://mev-boost-${NETWORK}.dappnode:18550"
    fi

    echo "[INFO - entrypoint] MEV Boost URL is set to $MEVBOOST_URL"
}

# Verify if the MEV Boost URL is reachable
# In case curl is not installed, MEV Boost is assumed to be available
_is_mevboost_available() {
    if [ -z "${MEVBOOST_URL:-}" ]; then
        echo "[ERROR - entrypoint] MEV Boost URL is not set"
        return 1
    fi

    if ! command -v curl >/dev/null; then
        echo "[WARN - entrypoint] curl is not installed. Skipping MEV Boost availability check"
        return 0
    fi

    if curl --retry 5 --retry-delay 5 --retry-all-errors "${MEVBOOST_URL}"; then
        echo "[INFO - entrypoint] MEV Boost is available"
        return 0
    else
        echo "[ERROR - entrypoint] MEV Boost is enabled but the package at ${MEVBOOST_URL} is not reachable. Disabling MEV Boost..."
        curl -X POST -G 'http://my.dappnode/notification-send' \
            --data-urlencode 'type=danger' \
            --data-urlencode title="${MEVBOOST_URL} can not be reached" \
            --data-urlencode 'body=Make sure the MEV Boost DNP for this network is available and running'
        return 1
    fi
}

# common_tools.sh APPENDED HERE BY WORKFLOW
