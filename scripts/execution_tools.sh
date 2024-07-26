#!/bin/sh

# Set the JWT path based on the consensus client selected in the Stakers tab
#
# Arguments:
#   $1: Network
#   $2: Supported networks
get_jwt_path() {
    network=$1
    supported_networks=$2
    security_base_path=$3

    consensus_short_dnp=$(_get_consensus_short_dnp "$network" "$supported_networks")

    echo "[INFO - entrypoint] Using $consensus_short_dnp JWT" >&2

    jwt_path="$security_base_path/$consensus_short_dnp/jwtsecret.hex"

    if [ ! -f "${jwt_path}" ]; then
        echo "[ERROR - entrypoint] JWT not found at ${jwt_path}" >&2
        exit 1
    fi

    echo "${jwt_path}"
}

# Post JWT to Package info tab in Dappmanager
# If the JWT is not posted, a warning message is logged, but the script continues
post_jwt_to_dappmanager() {
    jwt_path=$1

    echo "[INFO - entrypoint] Posting JWT to Dappmanager" >&2
    jwt=$(cat "${jwt_path}")

    if [ -z "$jwt" ]; then
        echo "[ERROR - entrypoint] JWT is empty" >&2
        return 1
    fi

    curl -X POST "http://my.dappnode/data-send?key=jwt&data=${jwt}" || {
        echo "[WARN - entrypoint] JWT could not be posted to package info" >&2
    }
}

# INTERNAL FUNCTIONS (Not meant to be called directly)

# Set the DNP name of the consensus client selected in the Stakers tab to the CONSENSUS_DNP environment variable
#
# Arguments:
#   $1: Network
#   $2: Supported networks
_get_consensus_short_dnp() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    consensus_dnp=$(get_value_from_global_env "CONSENSUS_CLIENT" "$network")

    consensus_short_dnp=$(_get_client_from_dnp "$consensus_dnp")

    echo "$consensus_short_dnp"
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
