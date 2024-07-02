#!/bin/sh

# Verify if the current NETWORK is supported
#
# Arguments:
#   $1: A space-separated list of supported networks
_verify_network_support() {
    supported_networks=$1 # List of supported networks

    if [ -z "$NETWORK" ]; then
        echo "[ERROR - entrypoint] NETWORK is not set"
        exit 1
    fi

    for supported_network in $supported_networks; do
        if [ "$supported_network" = "$NETWORK" ]; then
            return 0
        fi
    done

    echo "[ERROR - entrypoint] NETWORK $NETWORK is not supported"
    exit 1
}
