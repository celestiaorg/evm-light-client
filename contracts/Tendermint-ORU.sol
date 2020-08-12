// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.7.0 <8.0.0;

/// @title Optimistic rollup of a remote chain's Tendermint consensus.
contract Tendermint_ORU {
    ////////////////////////////////////
    // Immutable fields
    ////////////////////////////////////

    /// @notice Remote chain's genesis hash.
    bytes32 public immutable _genesisHash;

    ////////////////////////////////////
    // Mutable fields (storage)
    ////////////////////////////////////

    /// @notice Hashes of remote chain's block headers.
    /// @dev block height => block header hash
    mapping (uint256 => bytes32) public _headerHashes;

    ////////////////////////////////////
    // Constructor
    ////////////////////////////////////

    constructor(bytes32 genesisHash) {
        _genesisHash = genesisHash;
    }

    ////////////////////////////////////
    // Methods
    ////////////////////////////////////
}
