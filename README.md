# Staker package scripts

This repo contains some utility functions in shell script to help with the correct usage and configuration of any execution or conesnsus dappnode staker package

**Consensus tools:**

- `set_network_specific_config`: Sets the network specific configuration for the current network.
- `set_execution_dnp`: Sets the execution DNP for the current network.
- `set_engine_url`: Sets the Engine URL for the current network.
- `set_checkpointsync_url`: Sets the CheckpointSync URL for the current network.
- `set_mevboost_flag`: Sets the MEVBoost environment for the current network.
- `set_mevboost_url`: Sets the MEVBoost URL for the current network.
- `format_graffiti`: Formats the graffiti string to follow the correct format.

**Execution tools:**

N/A yet

### Example of usage

- Add to `bin` folder and load in entrypoint:

```Docker
ADD https://raw.githubusercontent.com/dappnode/staker-package-scripts/${STAKER_SCRIPTS_VERSION}/consensus-tools.sh /usr/local/bin/consensus-tools.sh
```

```Shell
#!/bin/bash

source /usr/local/bin/consensus-tools.sh
```

- Add to `/etc/profile.d`, it should be loaded in every shell session:

```Docker
ADD https://raw.githubusercontent.com/dappnode/staker-package-scripts/${STAKER_SCRIPTS_VERSION}/consensus-tools.sh /etc/profile.d/consensus-tools.sh
```
