#!/bin/sh

UPPERCASE_NETWORK=$(echo "${NETWORK}" | tr '[:lower:]' '[:upper:]')

# Set network-specific configuration
#
# Arguments:
#   $1: Network-specific flags (can be unset)
set_network_specific_config() {
    # In case specific flags need to be set for a network
    network_specific_flags=$1

    echo "[INFO - entrypoint] Initializing $NETWORK specific config for client"

    set_consensus_dnp

    # If consensus client is prysm-prater.dnp.dappnode.eth --> CLIENT=prysm
    short_consensus_name=$(echo "$CONSENSUS_DNP" | cut -d'.' -f1 | cut -d'-' -f1)

    set_jwt_path "$short_consensus_name"

    if [ -n "$network_specific_flags" ]; then
        export EXTRA_OPTS="${network_specific_flags} ${EXTRA_OPTS:-}"
    fi
}

# Set the DNP name of the consensus client selected in the Stakers tab to the CONSENSUS_DNP environment variable
set_consensus_dnp() {
    consensus_dnp_var="_DAPPNODE_GLOBAL_short_consensus_name_${UPPERCASE_NETWORK}"
    eval "CONSENSUS_DNP=\${$consensus_dnp_var}"
    export CONSENSUS_DNP
}

# Set the JWT path based on the consensus client selected in the Stakers tab
set_jwt_path() {
    short_consensus_name=$1
    echo "[INFO - entrypoint] Using $short_consensus_name JWT"
    export JWT_PATH="/security/$short_consensus_name/jwtsecret.hex"

    if [ ! -f "${JWT_PATH}" ]; then
        echo "[ERROR - entrypoint] JWT not found at ${JWT_PATH}"
        exit 1
    fi
}

# Post JWT to Package info tab in Dappmanager
# If the JWT is not posted, a warning message is logged, but the script continues
post_jwt_to_dappmanager() {
    echo "[INFO - entrypoint] Posting JWT to Dappmanager"
    jwt=$(cat "${JWT_PATH}")

    curl -X POST "http://my.dappnode/data-send?key=jwt&data=${jwt}" || {
        echo "[WARN - entrypoint] JWT could not be posted to package info"
    }
}
