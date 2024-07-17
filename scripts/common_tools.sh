#!/bin/sh

STAKER_GLOBAL_ENVS="EXECUTION_CLIENT CONSENSUS_CLIENT MEVBOOST"

# Internal function to add a flag to EXTRA_OPTS if it's not already included
#
# Arguments:
#   $1: Flag to add
add_flag_to_extra_opts() {
    flag=$1

    if [ -z "$flag" ]; then
        return
    fi

    # Extract the flag key before '=' or space (in case flag includes a value)
    flag_key=$(echo "$flag" | cut -d'=' -f1 | cut -d' ' -f1)

    if echo "$EXTRA_OPTS" | grep -q -- "$flag_key"; then
        echo "[INFO - internal] Flag '$flag_key' is already in EXTRA_OPTS"
    else
        echo "[INFO - internal] Adding flag '$flag' to EXTRA_OPTS"
        export EXTRA_OPTS="${flag} ${EXTRA_OPTS:-} "
    fi
}

# Get the value of a global environment variable
# Example: get_value_from_global_env "CONSENSUS_CLIENT" "mainnet" will return the value of _DAPPNODE_GLOBAL_CONSENSUS_CLIENT_MAINNET
#
# Arguments:
#   $1: Environment variable type (Must be one of the STAKER_GLOBAL_ENVS)
#   $2: Network
get_value_from_global_env() {
    env_type=$1
    network=$2

    if ! _is_value_in_array "${env_type}" "${STAKER_GLOBAL_ENVS}"; then
        echo "[ERROR - entrypoint] ${env_type} is not a valid global environment variable"
        exit 1
    fi

    uppercase_network=$(to_upper_case "$network")
    global_env_var="_DAPPNODE_GLOBAL_${env_type}_${uppercase_network}"
    eval "GLOBAL_ENV_VALUE=\${$global_env_var}"

    echo "${GLOBAL_ENV_VALUE}"
}

# Get the client alias from the DNP name (in dncore_network)
# Example: geth.dnp.dappnode.eth -> geth.dappnode
#
# Arguments:
#   $1: Client DNP name
get_client_network_alias() {
    client_dnp=$1

    case "$client_dnp" in
    *".public."*)
        # nethermind.public.dappnode.eth -> nethermind.public
        client_alias=$(echo "${client_dnp}" | cut -d'.' -f1-2)
        ;;
    *)
        # geth.dnp.dappnode.eth -> geth
        client_alias=$(echo "${client_dnp}" | cut -d'.' -f1)
        ;;
    esac

    echo "${client_alias}.dappnode"
}

# Convert a string to uppercase
#
# Arguments:
#   $1: String to convert
to_upper_case() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Convert a string to lowercase
#
# Arguments:
#   $1: String to convert
to_lower_case() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

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

    if _is_value_in_array "$network" "$supported_networks"; then
        return 0
    fi

    echo "[ERROR - entrypoint] NETWORK $network is not supported"
    exit 1
}

_is_value_in_array() {
    value=$1
    array=$2

    for item in $array; do
        if [ "$item" = "$value" ]; then
            return 0
        fi
    done

    return 1
}
