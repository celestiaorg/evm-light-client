// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

/// @notice Submission of remote chain block header.
struct HeaderSubmission {
    // Block header
    Header header;
    // Submitter
    address payable submitter;
    // Ethereum block number submission was made
    uint256 blockNumber;
    // Simple hash of previous block's commit in ABI encoded format
    bytes32 lastCommitHash;
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
    Commit lastCommit;
}

/// @title Optimistic rollup of a remote chain's Tendermint consensus.
contract Tendermint_ORU {
    ////////////////////////////////////
    // Events
    ////////////////////////////////////

    event BlockSubmitted(
        BareBlock bareBlock,
        bytes32 indexed headerHash,
        uint256 indexed height,
        HeaderSubmission headerSubmission
    );

    ////////////////////////////////////
    // Immutable fields
    ////////////////////////////////////

    /// @notice Remote chain's genesis hash.
    bytes32 public immutable _genesisHash;

    /// @notice Bond size.
    uint256 public immutable _bondSize;

    /// @notice Timeout for fraud proofs, in Ethereum blocks.
    uint256 public immutable _fraudTimeout;

    ////////////////////////////////////
    // Mutable fields (storage)
    ////////////////////////////////////

    /// @notice Hashes of submissions of remote chain's block headers. Once finalized, this is re-interpreted as a height.
    /// @dev header hash => header submission hash (height)
    mapping(bytes32 => bytes32) public _headerSubmissionHashes;

    /// @notice If a block is not finalized.
    /// @dev header hash => is not finalized
    mapping(bytes32 => bool) public _isNotFinalized;

    /// @notice Header hash of the tip block.
    bytes32 public _tipHash;

    ////////////////////////////////////
    // Constructor
    ////////////////////////////////////

    constructor(
        bytes32 genesisHash,
        uint256 bondSize,
        uint256 fraudTimeout
    ) public {
        _genesisHash = genesisHash;
        _bondSize = bondSize;
        _fraudTimeout = fraudTimeout;
    }

    ////////////////////////////////////
    // External functions
    ////////////////////////////////////

    /// @notice Submit a new bare block, placing a bond.
    function submitBlock(BareBlock calldata bareBlock, HeaderSubmission calldata prevSubmission) external payable {
        // Must send _bondSize ETH to submit a block
        require(msg.value == _bondSize);
        // Previous block header hash must be the tip
        require(bareBlock.header.lastBlockID == _tipHash);
        // Height must increment
        require(keccak256(abi.encode(prevSubmission)) == _headerSubmissionHashes[bareBlock.header.lastBlockID]);
        require(bareBlock.header.height == SafeMath.add(prevSubmission.header.height, 1));

        // Take simple hash of commit for previous block
        bytes32 lastCommitHash = keccak256(abi.encode(bareBlock.lastCommit));

        // TODO serialize header
        bytes memory serializedHeader;

        // Hash serialized header
        bytes32 headerHash = keccak256(serializedHeader);

        // Insert header as new tip
        HeaderSubmission memory headerSubmission = HeaderSubmission(
            bareBlock.header,
            msg.sender,
            block.number,
            lastCommitHash
        );
        _headerSubmissionHashes[headerHash] = keccak256(abi.encode(headerSubmission));
        _isNotFinalized[headerHash] = true;
        _tipHash = headerHash;

        emit BlockSubmitted(bareBlock, headerHash, bareBlock.header.height, headerSubmission);
    }

    /// @notice Prove a block was invalid, reverting it and orphaning its descendents.
    function proveFraud(
        bytes32 headerHash,
        HeaderSubmission calldata headerSubmission,
        HeaderSubmission calldata tipSubmission,
        Commit calldata commit
    ) external {
        // Check submission against storage
        require(keccak256(abi.encode(headerSubmission)) == _headerSubmissionHashes[headerHash]);
        // Block must not be finalized yet
        require(_isNotFinalized[headerHash]);

        // Block must be at most the same height as the tip
        // Note: orphaned blocks be pruned before submitting new blocks since
        // this check does not account for forks.
        require(keccak256(abi.encode(tipSubmission)) == _headerSubmissionHashes[_tipHash]);
        require(headerSubmission.header.height <= tipSubmission.header.height);

        // TODO serialize and Merkleize commit
        // TODO compare root against stored root
        // TODO process commit, check at least 2/3 of voting power

        // Reset storage
        delete _headerSubmissionHashes[headerHash];
        delete _isNotFinalized[headerHash];
        // Roll back the tip
        _tipHash = headerSubmission.header.lastBlockID;

        // Return half of bond to prover
        msg.sender.transfer(SafeMath.div(_bondSize, 2));
    }

    /// @notice Finalize blocks, returning the bond to the submitter.
    function finalizeBlocks(bytes32[] calldata headerHashes, HeaderSubmission[] calldata headerSubmissions) external {
        for (uint256 i = 0; i < headerHashes.length; i++) {
            bytes32 headerHash = headerHashes[i];
            HeaderSubmission memory headerSubmission = headerSubmissions[i];
            // Check submission against storage
            require(keccak256(abi.encode(headerSubmission)) == _headerSubmissionHashes[headerHash]);
            // Block must not be finalized yet
            require(_isNotFinalized[headerHash]);

            // Timeout must be expired in order to finalize a block
            require(block.number > SafeMath.add(headerSubmission.blockNumber, _fraudTimeout));

            // Re-interpret value as height
            _headerSubmissionHashes[headerHash] = bytes32(uint256(headerSubmission.header.height));
            // Reset storage
            delete _isNotFinalized[headerHash];

            // Return bond to submitter
            headerSubmission.submitter.transfer(_bondSize);
        }
    }

    /// @notice Prune blocks orphaned in a reversion.
    /// @dev Orphaned blocks must be pruned before submitting new blocks.
    function pruneBlocks(bytes32[] calldata headerHashes, HeaderSubmission[] calldata headerSubmissions) external {
        for (uint256 i = 0; i < headerHashes.length; i++) {
            bytes32 headerHash = headerHashes[i];
            HeaderSubmission memory headerSubmission = headerSubmissions[i];
            // Check submission against storage
            require(keccak256(abi.encode(headerSubmission)) == _headerSubmissionHashes[headerHash]);
            // Block must not be finalized yet
            require(_isNotFinalized[headerHash]);

            // Previous block must be orphaned
            require(_headerSubmissionHashes[headerSubmission.header.lastBlockID] == 0);

            // Reset storage
            delete _headerSubmissionHashes[headerHash];
            delete _isNotFinalized[headerHash];

            // Return half of bond to pruner
            msg.sender.transfer(SafeMath.div(_bondSize, 2));
        }
    }
}
