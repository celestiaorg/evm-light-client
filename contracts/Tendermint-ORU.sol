// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.7.0 <8.0.0;
pragma experimental ABIEncoderV2;

/// @notice Submission of remote chain block header.
struct HeaderSubmission {
    // Block header hash
    bytes32 digest;
    // Submitter
    address submitter;
    // Ethereum block number submission was made
    uint256 blockNumber;
}

/// @notice Remote chain block header.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#header
struct Header {
    uint64 height;
    uint64 timestamp;
    uint64 lastBlockID;
    bytes32 lastCommitRoot;
    bytes32 consensusRoot;
    bytes32 stateCommitment;
    bytes32 availableDataRoot;
    bytes32 proposerAddress; // Note: this needs to be converted to a 20-byte address when used
}

/// @notice Compact ECDSA signature.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#signature
struct Signature {
    bytes32 r;
    bytes32 vs;
}

/// @notice Tendermint signature.
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#commitsig
struct CommitSig {
    uint8 blockIDFlag;
    bytes32 validatorAddress; // Note: this needs to be converted to a 20-byte address when used
    uint64 timestamp;
    Signature signature;
}

/// @notice Tendermint commit (list of signatures).
/// @dev https://github.com/lazyledger/lazyledger-specs/blob/master/specs/data_structures.md#commit
struct Commit {
    uint64 height;
    uint64 round;
    uint64 blockID;
    CommitSig[] signatures;
}

/// @notice Bare minimim block data. Only contains the block header and commit.
struct BareBlock {
    Header header;
    Commit commit;
}

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

    /// @notice Submissions of remote chain's block headers.
    /// @dev block height => header submission
    mapping (uint256 => HeaderSubmission) public _headerSubmissions;

    ////////////////////////////////////
    // Constructor
    ////////////////////////////////////

    constructor(bytes32 genesisHash) {
        _genesisHash = genesisHash;
    }

    ////////////////////////////////////
    // Methods
    ////////////////////////////////////

    function submitBlock(BareBlock calldata bareBlock) public {

    }
}
