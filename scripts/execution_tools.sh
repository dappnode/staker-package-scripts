#!/bin/sh

# Set network-specific configuration
#
# Arguments:
#   $1: Network
#   $2: Supported networks
#   $3: Network-specific flags (optional)
set_execution_config_by_network() {
    network=$1
    supported_networks=$2
    network_specific_flags=$3 # Optional flags specific to the network

    echo "[INFO - entrypoint] Initializing $network specific config for client"

    _set_jwt_path "$network" "$supported_networks"

    add_flag_to_extra_opts "$network_specific_flags"

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

# Set the JWT path based on the consensus client selected in the Stakers tab
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_set_jwt_path() {
    network=$1
    supported_networks=$2

    _set_consensus_dnp "$network" "$supported_networks"

    consensus_client=$(_get_client_from_dnp "$CONSENSUS_DNP")

    echo "[INFO - entrypoint] Using $consensus_client JWT"
    export JWT_PATH="/security/$consensus_client/jwtsecret.hex"

    if [ ! -f "${JWT_PATH}" ]; then
        echo "[ERROR - entrypoint] JWT not found at ${JWT_PATH}"
        exit 1
    fi
}

# Set the DNP name of the consensus client selected in the Stakers tab to the CONSENSUS_DNP environment variable
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_set_consensus_dnp() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    uppercase_network=$(_to_upper_case "$network")
    consensus_dnp_var="_DAPPNODE_GLOBAL_CONSENSUS_CLIENT_${uppercase_network}"
    eval "CONSENSUS_DNP=\${$consensus_dnp_var}"
    export CONSENSUS_DNP
}

# Returns the short name of the consensus client
# Example: prysm-prater.dnp.dappnode.eth --> prysm
#
# Arguments:
#   $1: Consensus DNP name
_get_client_from_dnp() {
    consensus_dnp=$1

    echo "$consensus_dnp" | cut -d'.' -f1 | cut -d'-' -f1
}

# common_tools.sh APPENDED HERE BY WORKFLOW
