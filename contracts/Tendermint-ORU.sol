// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

/// @notice Submission of remote chain block header.
struct HeaderSubmission {
    // Remote chain block height
    uint64 height;
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
    bytes32 lastBlockID;
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

    /// @notice Bond size.
    uint256 public immutable _bondSize;

    ////////////////////////////////////
    // Mutable fields (storage)
    ////////////////////////////////////

    /// @notice Hashes of submissions of remote chain's block headers.
    /// @dev header hash => header submission hash
    mapping(bytes32 => bytes32) public _headerSubmissionHashes;

    /// @notice Hash of the tip block.
    bytes32 public _tipHash;

    ////////////////////////////////////
    // Constructor
    ////////////////////////////////////

    constructor(bytes32 genesisHash, uint256 bondSize) public {
        _genesisHash = genesisHash;
        _bondSize = bondSize;
    }

    ////////////////////////////////////
    // External functions
    ////////////////////////////////////

    /// @notice Submit a new bare block, placing a bond.
    function submitBlock(
        BareBlock calldata bareBlock,
        HeaderSubmission calldata parentSubmission
    ) external payable {
        // Must send _bondSize ETH to submit a block
        require(msg.value == _bondSize);
        // Parent must be the tip
        require(bareBlock.header.lastBlockID == _tipHash);
        // Height must increment
        bytes32 parentSubmissionHash = keccak256(abi.encode(parentSubmission));
        require(
            _headerSubmissionHashes[bareBlock.header.lastBlockID] ==
                parentSubmissionHash
        );
        require(bareBlock.header.height == SafeMath.add(parentSubmission, 1));

        // TODO serialize header
        // TODO hash serialized header
        bytes32 headerHash = bytes32(0);

        _headerSubmissionHashes[headerHash] = keccak256(
            abi.encode(
                HeaderSubmission(
                    bareBlock.header.height,
                    msg.sender,
                    block.number
                )
            )
        );
        _tipHash = headerHash;
    }

    /// @notice Prove a block was invalid, reverting it and orphaning its descendents.
    function proveFraud(bytes32 headerHash, bytes calldata proof) external {}

    /// @notice Finalize blocks, returning the bond to the submitter.
    function finalizeBlocks(
        bytes32[] calldata headerHashes,
        HeaderSubmission[] calldata headerSubmissions
    ) external {}

    /// @notice Prune orphaned blocks from a reversion.
    function pruneBlocks(
        bytes32[] calldata heaaderHashes,
        HeaderSubmission[] calldata headerSubmissions
    ) external {}
}
