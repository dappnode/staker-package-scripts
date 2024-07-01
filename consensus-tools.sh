#!/bin/sh

UPPERCASE_NETWORK=$(echo "${NETWORK}" | tr '[:lower:]' '[:upper:]')

set_network_specific_config() {
    export P2P_PORT="$1"

    echo "[INFO - entrypoint] Initializing $NETWORK specific config for client"

    set_engine_url
}

set_execution_dnp() {
    execution_dnp_var="_DAPPNODE_GLOBAL_EXECUTION_CLIENT_${UPPERCASE_NETWORK}"
    eval "EXECUTION_DNP=\${$execution_dnp_var}"
    export EXECUTION_DNP
}

set_engine_url() {
    set_execution_dnp

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

# shellcheck disable=SC2120 # This script is sourced
set_checkpointsync_url() {
    checkpoint_flag="$1"

    if [ -n "$CHECKPOINT_SYNC_URL" ]; then
        echo "[INFO - entrypoint] Checkpoint sync URL is set to $CHECKPOINT_SYNC_URL"
        export EXTRA_OPTS="${checkpoint_flag}=${CHECKPOINT_SYNC_URL} ${EXTRA_OPTS:-}"
    else
        echo "[WARN - entrypoint] Checkpoint sync URL is not set"
    fi
}

# shellcheck disable=SC2120 # This script is sourced
set_mevboost() {
    mevboost_flag="$1"
    skip_mevboost_url="$2"

    mevboost_enabled_var="_DAPPNODE_GLOBAL_MEVBOOST_${UPPERCASE_NETWORK}"

    # Using eval to check and assign the variable, ensuring it's not unbound
    eval "mevboost_enabled=\${${mevboost_enabled_var}:-false}"

    # shellcheck disable=SC2154
    if [ "${mevboost_enabled}" = "true" ]; then
        echo "[INFO - entrypoint] MEV Boost is enabled"
        set_mevboost_url

        if is_mevboost_available; then

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

set_mevboost_url() {
    # If network is mainnet and MEV-Boost is enabled, set the MEV-Boost URL
    if [ "${NETWORK}" = "mainnet" ]; then
        export MEVBOOST_URL="http://mev-boost.dappnode:18550"
    else
        export MEVBOOST_URL="http://mev-boost-${NETWORK}.dappnode:18550"
    fi

    echo "[INFO - entrypoint] MEV Boost URL is set to $MEVBOOST_URL"
}

is_mevboost_available() {
    if [ -z "${MEVBOOST_URL:-}" ]; then
        echo "[ERROR - entrypoint] MEV Boost URL is not set"
        return 1
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
