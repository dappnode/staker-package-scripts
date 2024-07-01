# Staker package scripts

This repo contains some utility functions in shell script to help with the correct usage and configuration of any execution or conesnsus dappnode staker package

**Consensus tools:**

Shell script including a set of handy functions to be used in the entrypoint of both `beacon-chain` and `validator` services of all consensus client packages

**Execution tools:**

Shell script including a set of handy functions to be used in the entrypoint of any execution package

### Example of usage (consensus-tools.sh)

- Add script to `/etc/profile.d` and load it in the entrypoint script:

```Docker
ADD https://raw.githubusercontent.com/dappnode/staker-package-scripts/${STAKER_SCRIPTS_VERSION}/consensus-tools.sh /etc/profile.d/consensus-tools.sh
```

```Shell
#!/bin/sh

. /etc/profile
```