#!/bin/sh

STAKER_GLOBAL_ENVS="EXECUTION_CLIENT CONSENSUS_CLIENT MEVBOOST"
AVAILABLE_NETWORKS="mainnet holesky gnosis lukso sepolia"

# Internal function to add a flag to EXTRA_OPTS if it's not already included
#
# Arguments:
#   $1: Flag to add
add_flag_to_extra_opts_safely() {
    extra_opts=$1
    flag=$2

    if [ -z "$flag" ]; then
        return
    fi

    # Extract the flag key before '=' or space (in case flag includes a value)
    flag_key=$(echo "$flag" | cut -d'=' -f1 | cut -d' ' -f1)

    if echo "$extra_opts" | grep -q -- "$flag_key"; then
        echo "[INFO - entrypoint] Flag '$flag_key' is already in EXTRA OPTS" >&2
    else
        echo "[INFO - entrypoint] Adding flag '$flag' to EXTRA OPTS" >&2
        extra_opts="${flag} ${extra_opts:-} "
    fi

    echo "[INFO - entrypoint] New EXTRA OPTS: $extra_opts" >&2

    echo "$extra_opts"
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
        echo "[ERROR - entrypoint] ${env_type} is not a valid global environment variable" >&2
        exit 1
    fi

    uppercase_network=$(to_upper_case "$network")
    global_env_var="_DAPPNODE_GLOBAL_${env_type}_${uppercase_network}"
    eval "global_env_value=\${$global_env_var}"

    # shellcheck disable=SC2154
    echo "${global_env_value}"
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

get_jwt_secret_by_network() {
    network=$1

    case $network in
    mainnet)
        jwt="7ad9cfdec75eceb662f5e48f5765701c17f51a5233a60fbcfa5f9e4000000001"
        ;;
    holesky)
        jwt="7ad9cfdec75eceb662f5e48f5765701c17f51a5233a60fbcfa5f9e4000004268"
        ;;
    gnosis)
        jwt="7ad9cfdec75eceb662f5e48f5765701c17f51a5233a60fbcfa5f9e4000000064"
        ;;
    lukso)
        jwt="7ad9cfdec75eceb662f5e48f5765701c17f51a5233a60fbcfa5f9e400000002a"
        ;;
    sepolia)
        jwt="7ad9cfdec75eceb662f5e48f5765701c17f51a5233a60fbcfa5f9e4000aa36a7"
        ;;
    *)
        echo "[ERROR - entrypoint] NETWORK $network is not supported" >&2
        exit 1
        ;;
    esac

    echo "[INFO - entrypoint] JWT secret for $network is: $jwt" >&2

    echo "$jwt"
}

get_web3signer_domain() {
    network=$1
    supported_networks=$2

    _verify_network_support "$network" "$supported_networks"

    if [ "$network" = "mainnet" ]; then
        web3signer_domain="web3signer.dappnode"
    else
        web3signer_domain="web3signer-${network}.dappnode"
    fi

    echo "${web3signer_domain}"
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
        echo "[ERROR - entrypoint] NETWORK is not set" >&2
        exit 1
    fi

    if _is_value_in_array "$network" "$supported_networks"; then
        return 0
    fi

    echo "[ERROR - entrypoint] NETWORK $network is not supported" >&2
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
