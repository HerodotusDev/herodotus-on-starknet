# Herodotus on Starknet

This repository contains and implements smart contracts deployed on Starknet.

This repository contains the following modules:

- Core - Implements the core logic behind Herodotus.
- Remappers - Implements a util allowing to map arbitrary timestamps to L1 block numbers.
- Turbo - Acts as a frontend to the Core contracts, provides great UX to developers and simplifies the integration.
- L1 - Smart contracts deployed on Ethereum L1 responsible for synchronizing with L1.

# Core

This module is responsible for:

- Processing new block headers and growing the MMR.
- Receiving and handling L1 messages containing blockhashes and Poseidon roots of the MMR which generation has been ShARP proven.
- Verifying state proofs and saving the proven values in the `FactsRegistry`

# Timestamps to block numbers mapper

This module implements the logic described in this doc:
https://herodotus.notion.site/Blocks-timestamp-to-number-mapper-6d6df20f31e24afdba89fe67c04ec5e2?pvs=4

# Turbo

WIP -> EVM implementation https://github.com/HerodotusDev/herodotus-evm

More info:
https://www.notion.so/herodotus/Herodotus-on-Starknet-Smart-contracts-flow-bb42da2b3f434c84900682ee8a954531

Herodotus Dev - 2023.
