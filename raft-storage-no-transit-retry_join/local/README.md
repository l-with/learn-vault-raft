# Create a Vault HA cluster locally on your machine

These assets are provided to perform the tasks described in the [Vault HA Cluster with Integrated Storage](https://learn.hashicorp.com/vault/operations/raft-storage) guide.

---

## Setup script, network and configuration

1. Set the `cluster.sh` file to executable:

    ```shell
    $ chmod +x cluster.sh
    ```

1. Set up the local loopback addresses for each Vault:

    ```shell
    $ ./cluster.sh create network

    [vault_2] Enabling local loopback on 127.0.0.2 (requires sudo)
    Password:

    [vault_3] Enabling local loopback on 127.0.0.3 (requires sudo)
    ```

    > This operation requires a user with sudo access. You will be prompted to enter
    your password.

1. Create the configuration for each Vault:

    ```shell
    $ ./cluster.sh create config
    [vault_1] Creating configuration
      - creating $DEMO_HOME/config-vault_1.hcl
    [vault_2] Creating configuration
      - creating $DEMO_HOME/config-vault_2.hcl
      - creating $DEMO_HOME/raft-vault_2
    [vault_3] Creating configuration
      - creating $DEMO_HOME/config-vault_3.hcl
      - creating $DEMO_HOME/raft-vault_3
    ```

## Setup Vault nodes

You can setup the nodes individually as described below or perform the setup for
all nodes with `./cluster.sh setup all`.

1. Setup **vault_1**:

    ```shell
    $ ./cluster.sh setup vault_1
    [vault_1] starting Vault server @ http://127.0.0.1:8200

    [vault_1] initializing and capturing the unseal key and root token

    [vault_1] Unseal key: Q4eS1oGlVtoetJcXleWNoskDwz4SQXQQ0x8SyIvM2WE=
    [vault_1] Root token: s.K9SANPJSl7oluQNm919bgh9c

    [vault_1] unsealing and logging in
    Key             Value
    ---             -----
    Seal Type       shamir
    Initialized     true
    Sealed          false
    Total Shares    1
    Threshold       1
    Version         1.3.0
    Cluster Name    vault-cluster-cfbd3810
    Cluster ID      05bdd1d1-5c65-fee4-d2aa-357ccb32eaa6
    HA Enabled      false
    Success! You are now authenticated. The token information displayed below
    is already stored in the token helper. You do NOT need to run "vault login"
    again. Future Vault requests will automatically use this token.
    ...
    ```

1. Setup **vault_2**:

    ```shell
    $ ./cluster.sh setup vault_2
    [vault_2] starting Vault server @ http://127.0.0.2:8200
   
    [vault_2] unsealing with unseal key from vault_1
   
    ...
 ```

1. Setup **vault_3**:

    ```shell
    $ ./cluster.sh setup vault_3
    [vault_3] starting Vault server @ http://127.0.0.3:8200
   
    [vault_3] unsealing with unseal key from vault_1
    
    ...
    ```


## View the cluster configuration from any cluster member:

    ```shell
    $ ./cluster.sh vault_1 operator raft list-peers
    $ ./cluster.sh vault_2 operator raft list-peers
    $ ./cluster.sh vault_3 operator raft list-peers
   ```

    The output should show that `vault_2` and `vault_3` are cluster members as follower.

    ```
    Node       Address           State       Voter
    ----       -------           -----       -----
    vault_1    127.0.0.1:8201    leader      true
    vault_2    127.0.0.2:8201    follower    true
    vault_3    127.0.0.3:8201    follower    true
    ```

# Interacting with the nodes

Get the status of all nodes:

```sh
$ ./cluster.sh status
```

Stop an individual node or all nodes:

```sh
$ ./cluster.sh stop [vault_1|vault_2|vault_3|all]
```

Start an individual node or all nodes:

```sh
$ ./cluster.sh start [vault_1|vault_2|vault_3|all]
```

Unseal an individual node or all nodes:

```sh
$ ./cluster.sh unseal [vault_1|vault_2|vault_3|all]
```

Issue a Vault command, like `status`, targeting one of the nodes:

```sh
$ ./cluster.sh vault_1 status
$ ./cluster.sh vault_2 status
$ ./cluster.sh vault_3 status
```

# Clean up

Stop all Vaults, remove networking, configuration, storage, and logs:

```shell
$ ./cluster.sh clean
Found 4 Vault services

Stopping 4 Vault services

Cleaning up the HA cluster. Removing:
 - local loopback address for [vault_2], [vault_3], and [vault_4[
 - configuration files
 - raft storage directory
 - log files
 - unseal / recovery keys

Removing local loopback address: 127.0.0.2 (sudo required)
Password:

Removing local loopback address: 127.0.0.3 (sudo required)

Removing local loopback address: 127.0.0.4 (sudo required)

Removing configuration file config-vault_1.hcl
Removing configuration file config-vault_2.hcl
Removing configuration file config-vault_3.hcl
Removing configuration file config-vault_4.hcl
Removing raft storage file raft-vault_2
Removing raft storage file raft-vault_3
Removing raft storage file raft-vault_4
Removing log file vault_1.log
Removing log file vault_2.log
Removing log file vault_3.log
Removing log file vault_4.log
Removing key unseal_key-vault_1
Removing key recovery_key-vault_2
Clean complete
```
