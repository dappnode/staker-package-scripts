#!/bin/sh

# Set network-specific configuration
#
# Arguments:
#   $1: Supported networks
#   $2: Network-specific flags (can be unset)
set_execution_config_by_network() {
    supported_networks=$1
    network_specific_flags=$2 # In case specific flags need to be set for a network

    echo "[INFO - entrypoint] Initializing $NETWORK specific config for client"

    _set_jwt_path "$supported_networks"

    if [ -n "$network_specific_flags" ]; then
        export EXTRA_OPTS="${network_specific_flags} ${EXTRA_OPTS:-}"
    fi
}

# Post JWT to Package info tab in Dappmanager
# If the JWT is not posted, a warning message is logged, but the script continues
post_jwt_to_dappmanager() {

    if [ -z "$JWT_PATH" ]; then
        echo "[WARN - entrypoint] JWT_PATH is not set. Cannot post JWT to Dappmanager"
        return 1
    fi

    echo "[INFO - entrypoint] Posting JWT to Dappmanager"
    jwt=$(cat "${JWT_PATH}")

    curl -X POST "http://my.dappnode/data-send?key=jwt&data=${jwt}" || {
        echo "[WARN - entrypoint] JWT could not be posted to package info"
    }
}

# INTERNAL FUNCTIONS (Not meant to be called directly)

_to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Set the JWT path based on the consensus client selected in the Stakers tab
#
# Arguments:
#   $1: Supported networks
_set_jwt_path() {
    supported_networks=$1

    _set_consensus_dnp "$supported_networks"

    short_consensus_name=$(_shorten_consensus_name "$CONSENSUS_DNP")

    echo "[INFO - entrypoint] Using $short_consensus_name JWT"
    export JWT_PATH="/security/$short_consensus_name/jwtsecret.hex"

    if [ ! -f "${JWT_PATH}" ]; then
        echo "[ERROR - entrypoint] JWT not found at ${JWT_PATH}"
        exit 1
    fi
}

# Set the DNP name of the consensus client selected in the Stakers tab to the CONSENSUS_DNP environment variable
#
# Arguments:
#   $1: Supported networks
_set_consensus_dnp() {
    supported_networks=$1

    _verify_network_support "$supported_networks"

    uppercase_network=$(_to_upper_case "$NETWORK")
    consensus_dnp_var="_DAPPNODE_GLOBAL_CONSENSUS_CLIENT_${uppercase_network}"
    eval "CONSENSUS_DNP=\${$consensus_dnp_var}"
    export CONSENSUS_DNP
}

# Returns the short name of the consensus client
# Example: prysm-prater.dnp.dappnode.eth --> prysm
#
# Arguments:
#   $1: Consensus DNP name
_shorten_consensus_name() {
    consensus_dnp=$1

    echo "$consensus_dnp" | cut -d'.' -f1 | cut -d'-' -f1
}

# common_tools.sh APPENDED HERE BY WORKFLOW
