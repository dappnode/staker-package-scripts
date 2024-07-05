#!/bin/sh

MEVBOOST_SUPPORTED_NETWORKS="mainnet holesky"

# Set network-specific configuration
#
# Arguments:
#   $1: Network --> e.g. "mainnet"
#   $2: Supported networks --> e.g. "mainnet testnet"
#   $3: Network-specific flags (can be unset) --> e.g. "--foo --bar"
set_beacon_config_by_network() {
    network=$1
    supported_networks=$2
    network_specific_flags=$3 # In case specific flags need to be set for a network

    echo "[INFO - entrypoint] Initializing $network specific config for beacon node"

    _set_engine_api_url "$network" "$supported_networks"

    add_flag_to_extra_opts "$network_specific_flags"
}

# Set network-specific configuration for validator
#
# Arguments:
#   $1: Network --> e.g. "mainnet"
#   $2: Supported networks --> e.g. "mainnet testnet"
#   $3: Client --> e.g. "nimbus"
#   $4: Network-specific flags (optional) --> e.g. "--foo --bar"
set_validator_config_by_network() {
    network=$1
    supported_networks=$2
    client=$3
    network_specific_flags=$4

    echo "[INFO - entrypoint] Initializing $network specific config for validator"

    _set_validator_api_urls "$network" "$supported_networks" "$client"

    add_flag_to_extra_opts "$network_specific_flags"
}

# Set the checkpoint sync URL to the EXTRA_OPTS environment variable
# The beacon node will use this URL to sync the checkpoints
#
# Arguments:
#   $1: Checkpoint flag
#   $2: Checkpoint URL
#
# shellcheck disable=SC2120 # This script is sourced
set_checkpoint_sync_url() {
    checkpoint_flag="$1"
    checkpoint_url="$2"

    if [ -n "$checkpoint_url" ]; then
        echo "[INFO - entrypoint] Checkpoint sync URL is set to $checkpoint_url"
        add_flag_to_extra_opts "${checkpoint_flag}=${checkpoint_url}"
    else
        echo "[WARN - entrypoint] Checkpoint sync URL is not set"
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
set_mevboost_flag() {
    network=$1
    mevboost_flag=$2
    skip_mevboost_url=$3

    uppercase_network=$(_to_upper_case "$network")
    mevboost_enabled_var="_DAPPNODE_GLOBAL_MEVBOOST_${uppercase_network}"

    # Using eval to check and assign the variable, ensuring it's not unbound
    eval "mevboost_enabled=\${${mevboost_enabled_var}:-false}"

    # shellcheck disable=SC2154
    if [ "${mevboost_enabled}" = "true" ]; then

        echo "[INFO - entrypoint] MEV Boost is enabled"
        _set_mevboost_url "$network"

        if _is_mevboost_available; then

            if [ "${skip_mevboost_url}" = "true" ]; then
                add_flag_to_extra_opts "${mevboost_flag}"
            else
                add_flag_to_extra_opts "${mevboost_flag}=${MEVBOOST_URL}"
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

validate_fee_recipient() {

    if echo "$FEE_RECIPIENT" | grep -Eq '^0x[a-fA-F0-9]{40}$'; then
        echo "[INFO - entrypoint] Fee recipient address (${FEE_RECIPIENT}) is valid"
    else
        echo "[WARN - entrypoint] Fee recipient address is invalid. It should be an Ethereum address"
        echo "[WARN - entrypoint] Setting the fee recipient address to the burn address"
        export FEE_RECIPIENT="0x0000000000000000000000000000000000000000"
    fi

}

# INTERNAL FUNCTIONS (Not meant to be called directly)

# Set the engine URL based on the execution client selected in the Stakers tab
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_set_engine_api_url() {
    network=$1
    supported_networks=$2

    _set_execution_dnp "$network" "$supported_networks"

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

    export ENGINE_API_URL="http://${execution_subdomain}.dappnode:8551"
}

# Set the validator API URLs based on the network and client
#
# Arguments:
#   $1: Network
#   $2: Supported networks
#   $3: Client
_set_validator_api_urls() {
    network=$1
    supported_networks=$2
    client=$3

    _verify_network_support "$network" "$supported_networks"

    if [ -z "$client" ]; then
        echo "[ERROR - entrypoint] Client is not set"
        exit 1
    fi

    if [ "$client" = "nimbus" ]; then
        beacon_service="beacon-validator"
        beacon_port="4500"
    else
        beacon_service="beacon-chain"
        beacon_port="3500"
    fi

    if [ "${network}" = "mainnet" ]; then
        export WEB3SIGNER_API_URL="http://web3signer.web3signer.dappnode:9000"
        export BEACON_API_URL="http://${beacon_service}.${client}.dappnode:${beacon_port}"

    else
        export WEB3SIGNER_API_URL="http://web3signer.web3signer-${network}.dappnode:9000"
        export BEACON_API_URL="http://${beacon_service}.${client}-${network}.dappnode:${beacon_port}"

    fi

    echo "[INFO - entrypoint] Web3signer URL is set to $WEB3SIGNER_API_URL"
    echo "[INFO - entrypoint] Beacon API URL is set to $BEACON_API_URL"

}

# Set the DNP name of the execution client selected in the Stakers tab to the EXECUTION_DNP environment variable
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_set_execution_dnp() {
    network=$1
    supported_networks=$2

    _verify_network_support "$supported_networks"

    uppercase_network=$(_to_upper_case "$network")
    execution_dnp_var="_DAPPNODE_GLOBAL_EXECUTION_CLIENT_${uppercase_network}"
    eval "EXECUTION_DNP=\${$execution_dnp_var}"

    if [ -z "$EXECUTION_DNP" ]; then
        echo "[ERROR - entrypoint] Execution client is not set for $network"
        exit 1
    fi

    export EXECUTION_DNP
}

# Set the MEV Boost URL based on the network
#
# Arguments:
#   $1: Network
_set_mevboost_url() {
    network=$1
    verify_network_support "$network" "$MEVBOOST_SUPPORTED_NETWORKS"

    # If network is mainnet and MEV-Boost is enabled, set the MEV-Boost URL
    if [ "${network}" = "mainnet" ]; then
        export MEVBOOST_URL="http://mev-boost.dappnode:18550"
    else
        export MEVBOOST_URL="http://mev-boost-${network}.dappnode:18550"
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
