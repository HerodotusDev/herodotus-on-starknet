# Herodotus on Starknet

This repository contains and implements smart contracts deployed on Starknet.

This repository contains the following modules:

-   Core - Implements the core logic behind Herodotus.
-   Remappers - Implements a util allowing to map arbitrary timestamps to L1 block numbers.
-   Turbo - Acts as a frontend to the Core contracts, provides great UX to developers and simplifies the integration.
-   L1 - Smart contracts deployed on Ethereum L1 responsible for synchronizing with L1.

# Core

This module is responsible for:

-   Processing new block headers and growing the MMR.
-   Receiving and handling L1 messages containing blockhashes and Poseidon roots of the MMR which generation has been SHARP proven.
-   Verifying state proofs and saving the proven values in the `FactsRegistry`

## Error codes

### Headers Store

-   `ONLY_COMMITMENTS_INBOX` - Only commitments inbox (address saved in `commitments_inbox` variable) can send messages to this function.

-   `SRC_MMR_NOT_FOUND` - Source MMR (one from which the branch is created) with provided MMR ID does not exist in the store.

-   `SRC_MMR_ID_0_NOT_ALLOWED` - Source MMR (one from which the branch is created) with ID 0 is not allowed.

-   `NEW_MMR_ID_0_NOT_ALLOWED` - New MMR (one that is created from source branch) with ID 0 is not allowed.

-   `ROOT_0_NOT_ALLOWED` - Creating MMR with root 0 is not allowed.

-   `NEW_MMR_ALREADY_EXISTS` - New MMR (one that is created from source branch) with provided ID already exists in the store.

-   `MMR_NOT_FOUND` - MMR with provided ID does not exist in the store.

-   `PROOF_AND_REF_BLOCK_NOT_ALLOWED` - `process_batch` can't be called with both proof and reference block. Please select either one.

-   `INVALID_HEADER_RLP` - Provided header RLP is invalid.

-   `INVALID_MMR_PROOF` - Provided MMR proof (`proof` or `peaks` or both) is invalid.

-   `INVALID_START_BLOCK` - Cannot read block number from the first header RLP.

-   `BLOCK_NOT_RECEIVED` - Block which was referenced in `process_batch` was not written to the store with `receive_hash` function.

-   `INVALID_INITIAL_HEADER_RLP` - First header RLP didn't match the reference block.

-   `MMR_APPEND_FAILED` - Append to MMR function failed, most likely due to invalid peaks.

-   `INVALID_PARENT_HASH_RLP` - Could not read parent hash from the provided header RLP.

### Commitments Inbox

-   `ONLY_OWNER` - Only owner can call this function.

-   `ONLY_L1_MESSAGE_SENDER` - Only L1 message sender can call this function.

# Timestamps to block numbers mapper

This module implements the logic described in this doc:
https://herodotus.notion.site/Blocks-timestamp-to-number-mapper-6d6df20f31e24afdba89fe67c04ec5e2?pvs=4

# Turbo

WIP -> EVM implementation https://github.com/HerodotusDev/herodotus-evm

More info:
https://www.notion.so/herodotus/Herodotus-on-Starknet-Smart-contracts-flow-bb42da2b3f434c84900682ee8a954531

# Dependencies

This repository highly relies on the work implemented in:
https://github.com/HerodotusDev/cairo-lib

Herodotus Dev Ltd - 2023.
