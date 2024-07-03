#!/bin/sh

# Verify if the current network is supported
#
# Arguments:
#   $1: Network to verify
#   $2: A space-separated list of supported networks
_verify_network_support() {
    network=$1
    supported_networks=$2

    if [ -z "$network" ]; then
        echo "[ERROR - entrypoint] NETWORK is not set"
        exit 1
    fi

    for supported_network in $supported_networks; do
        if [ "$supported_network" = "$network" ]; then
            return 0
        fi
    done

    echo "[ERROR - entrypoint] NETWORK $network is not supported"
    exit 1
}

# Convert a string to uppercase
#
# Arguments:
#   $1: String to convert
_to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}
