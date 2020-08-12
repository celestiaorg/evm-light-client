// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

/// @notice Submission of remote chain block header.
struct HeaderSubmission {
    // Remote chain block height
    uint64 height;
    // Submitter
    address payable submitter;
    // Ethereum block number submission was made
    uint256 blockNumber;
    // Previous block header hash
    bytes32 prevHash;
    // If this block is not finalized
    bool isNotFinalized;
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
    // Events
    ////////////////////////////////////

    event BlockSubmitted(BareBlock bareBlock, bytes32 indexed headerHash);

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

    /// @notice Submissions of remote chain's block headers.
    /// @dev header hash => header submission
    mapping(bytes32 => HeaderSubmission) public _headerSubmissions;

    /// @notice Hash of the tip block.
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
    function submitBlock(BareBlock calldata bareBlock) external payable {
        // Must send _bondSize ETH to submit a block
        require(msg.value == _bondSize);
        // Previous block header hash must be the tip
        require(bareBlock.header.lastBlockID == _tipHash);
        // Height must increment
        HeaderSubmission memory prevSubmission = _headerSubmissions[bareBlock.header.lastBlockID];
        require(bareBlock.header.height == SafeMath.add(prevSubmission.height, 1));

        // TODO serialize and Merkleize commit
        // TODO check commit matches

        // TODO serialize header
        bytes memory serializedHeader;
        // Hash serialized header
        bytes32 headerHash = keccak256(serializedHeader);

        // Insert header as new tip
        _headerSubmissions[headerHash] = HeaderSubmission(
            bareBlock.header.height,
            msg.sender,
            block.number,
            bareBlock.header.lastBlockID,
            true
        );
        _tipHash = headerHash;

        emit BlockSubmitted(bareBlock, headerHash);
    }

    /// @notice Prove a block was invalid, reverting it and orphaning its descendents.
    function proveFraud(bytes32 headerHash, bytes calldata proof) external {
        // Load submission from storage
        HeaderSubmission memory headerSubmission = _headerSubmissions[headerHash];

        // TODO verify proof

        // Reset all fields (clearing height indicates orphaned block)
        delete headerSubmission.height;
        delete headerSubmission.submitter;
        delete headerSubmission.blockNumber;
        delete headerSubmission.prevHash;
        delete headerSubmission.isNotFinalized;

        // Write resets to storage
        _headerSubmissions[headerHash] = headerSubmission;

        // Return half of bond to prover
        msg.sender.transfer(SafeMath.div(_bondSize, 2));
    }

    /// @notice Finalize blocks, returning the bond to the submitter.
    function finalizeBlocks(bytes32[] calldata headerHashes) external {
        for (uint256 i = 0; i < headerHashes.length; i++) {
            // Load submission from storage
            HeaderSubmission memory headerSubmission = _headerSubmissions[headerHashes[i]];
            // Block must not be finalized yet
            require(headerSubmission.isNotFinalized);

            // Timeout must be expired in order to finalize a block
            require(block.number > SafeMath.add(headerSubmission.blockNumber, _fraudTimeout));

            // Reset unnecessary fields (to refund some gas)
            address payable submitter = headerSubmission.submitter;
            delete headerSubmission.submitter;
            delete headerSubmission.blockNumber;
            delete headerSubmission.prevHash;
            delete headerSubmission.isNotFinalized;

            // Write resets to storage
            _headerSubmissions[headerHashes[i]] = headerSubmission;

            // Return bond to submitter
            submitter.transfer(_bondSize);
        }
    }

    /// @notice Prune blocks orphaned in a reversion.
    function pruneBlocks(bytes32[] calldata headerHashes) external {
        for (uint256 i = 0; i < headerHashes.length; i++) {
            // Load submission from storage
            HeaderSubmission memory headerSubmission = _headerSubmissions[headerHashes[i]];
            // Block must not be finalized yet
            require(headerSubmission.isNotFinalized);

            // Previous block must be orphaned
            require(_headerSubmissions[headerSubmission.prevHash].height == 0);

            // Reset all fields (clearing height indicates orphaned block)
            delete headerSubmission.height;
            delete headerSubmission.submitter;
            delete headerSubmission.blockNumber;
            delete headerSubmission.prevHash;
            delete headerSubmission.isNotFinalized;

            // Write resets to storage
            _headerSubmissions[headerHashes[i]] = headerSubmission;

            // Return half of bond to pruner
            msg.sender.transfer(SafeMath.div(_bondSize, 2));
        }
    }
}
