# VoiceCult.Fun
We build VoiceCult.fun, combining the power of community building from pump.fun, the fun and tap-to-earn mechanism from notcoin then added our own cherry on top, voice chant, where project creator and communities can submit their chant in support of their cult/project and get airdrop.


## V1 Features
-   **Tap-to-airdrop**: get airdrop allocation by tapping to your cult
-   **Cult Leaderboard**: climb leaderboard to get more exposure
-   **Voice Chant**: get +50 extra tap per voice chant🗣️🔥
-   **Human verification**: fck the bots. it ruins vibes. thanks worldcoin🔥


## VC Scroll Sepolia contracts:
VoicecultTokenDeployer: [0x64DFe58baB099d77c4C445A1bd6BD2401d5999e0](https://sepolia.scrollscan.dev/address/0x64DFe58baB099d77c4C445A1bd6BD2401d5999e0)

VoicecultPool: [0xaeB6B70C7dD4d1E9fa0292F47dFf68C51F60416F](https://sepolia.scrollscan.dev/address/0xaeB6B70C7dD4d1E9fa0292F47dFf68C51F60416F)

TxFeeDistributor: [0x3d430A2d2b86941300BA83b078A65cD8E6766fA8](https://sepolia.scrollscan.dev/address/0x3d430A2d2b86941300BA83b078A65cD8E6766fA8)

VcStorage: [0x3F71d6B75B9A27dD5D70A5712D2B8334Ba8976AB](https://sepolia.scrollscan.dev/address/0x3F71d6B75B9A27dD5D70A5712D2B8334Ba8976AB)

VcEventTracker: [0xf1d992D4cD499BF93863bc6ec84556FFBB4e6224](https://sepolia.scrollscan.dev/address/0xf1d992D4cD499BF93863bc6ec84556FFBB4e6224)

ERC20 Implementation: [0x79d48Fd39c1bdea02a049e4E0eD80cf33A16916a](https://sepolia.scrollscan.dev/address/0x79d48Fd39c1bdea02a049e4E0eD80cf33A16916a)

## VC Manta Sepolia contracts:
VoicecultTokenDeployer: [0x916f9E363fa9249B294028F9a95d00CDc5ed86E6](https://pacific-explorer.sepolia-testnet.manta.network/address/0x916f9E363fa9249B294028F9a95d00CDc5ed86E6)

VoicecultPool: [0x0EB45B73d28890Ab655fEEe0EeCaB70C0f363c5a](https://pacific-explorer.sepolia-testnet.manta.network/address/0x0EB45B73d28890Ab655fEEe0EeCaB70C0f363c5a)

TxFeeDistributor: [0x301549209977244c98F3047d339C14ea152FE626](https://pacific-explorer.sepolia-testnet.manta.network/address/0x301549209977244c98F3047d339C14ea152FE626)

VcStorage: [0x1e930A651622798Fb79E75dE7D0E5e1C3a7bd5bE](https://pacific-explorer.sepolia-testnet.manta.network/address/0x1e930A651622798Fb79E75dE7D0E5e1C3a7bd5bE)

VcEventTracker: [0x79c2575F15E5e25124ef245BDEa780286cfefcd9](https://pacific-explorer.sepolia-testnet.manta.network/address/0x79c2575F15E5e25124ef245BDEa780286cfefcd9)

ERC20 Implementation: [0xEc77443771690872eD148a2f7cCDD3B4CF8Bc477](https://pacific-explorer.sepolia-testnet.manta.network/address/0xEc77443771690872eD148a2f7cCDD3B4CF8Bc477)

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
