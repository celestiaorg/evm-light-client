// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./Serializer.sol";

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

/// @title Optimistic rollup of a remote chain's Tendermint consensus.
contract Tendermint_ORU {
    using Serializer for Header;
    using Serializer for Signature;
    using Serializer for CommitSig;
    using Serializer for Commit;
    using Serializer for LightBlock;

    ////////////////////////////////////
    // Events
    ////////////////////////////////////

    event BlockSubmitted(
        LightBlock lightBlock,
        bytes32 indexed headerHash,
        uint256 indexed height,
        HeaderSubmission headerSubmission
    );

    ////////////////////////////////////
    // Immutable fields
    ////////////////////////////////////

    /// @notice Remote chain's genesis hash.
    bytes32 public immutable _genesisHash;

    /// @notice Genesis submission hash.
    bytes32 public immutable _genesisSubmissionHash;

    /// @notice Bond size.
    uint256 public immutable _bondSize;

    /// @notice Timeout for fraud proofs, in Ethereum blocks.
    uint256 public immutable _fraudTimeout;

    ////////////////////////////////////
    // Mutable fields (storage)
    ////////////////////////////////////

    /// @notice Hashes of submissions of remote chain's block headers.
    /// @dev header hash => header submission hash
    mapping(bytes32 => bytes32) public _headerSubmissionHashes;

    /// @notice Height of submissions.
    /// @dev header submission hash => height
    mapping(bytes32 => uint64) public _headerHeights;

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
        bytes32 genesisSubmissionHash,
        uint256 bondSize,
        uint256 fraudTimeout
    ) public {
        _genesisHash = genesisHash;
        _genesisSubmissionHash = genesisSubmissionHash;
        _bondSize = bondSize;
        _fraudTimeout = fraudTimeout;

        // The genesis block is already finalized implicitly, so we simply set the height to 1
        _headerHeights[genesisSubmissionHash] = 1;

        // Set the tip hash
        _tipHash = genesisHash;
    }

    ////////////////////////////////////
    // External functions
    ////////////////////////////////////

    /// @notice Submit a new bare block, placing a bond.
    function submitBlock(LightBlock memory lightBlock, bytes32 prevSubmissionHash) external payable {
        // Must send _bondSize ETH to submit a block
        require(msg.value == _bondSize);
        // Previous block header hash must be the tip
        require(lightBlock.header.lastBlockID == _tipHash);
        // Height must increment
        // Note: orphaned blocks be pruned before submitting new blocks since
        // this check does not account for forks.
        require(lightBlock.header.height == SafeMath.add(_headerHeights[prevSubmissionHash], 1));

        // Take simple hash of commit for previous block
        bytes32 lastCommitHash = keccak256(lightBlock.lastCommit.serialize());

        // Serialize header
        bytes memory serializedHeader = lightBlock.header.serialize();

        // Hash serialized header
        bytes32 headerHash = keccak256(serializedHeader);

        // Insert header as new tip
        HeaderSubmission memory headerSubmission = HeaderSubmission(
            lightBlock.header,
            msg.sender,
            block.number,
            lastCommitHash
        );
        bytes32 headerSubmissionHash = keccak256(abi.encode(headerSubmission));
        _headerSubmissionHashes[headerHash] = headerSubmissionHash;
        _headerHeights[headerSubmissionHash] = lightBlock.header.height;
        _isNotFinalized[headerHash] = true;
        _tipHash = headerHash;

        emit BlockSubmitted(lightBlock, headerHash, lightBlock.header.height, headerSubmission);
    }

    /// @notice Prove a block was invalid, reverting it and orphaning its descendents.
    function proveFraud(
        bytes32 headerHash,
        HeaderSubmission calldata headerSubmission,
        HeaderSubmission calldata tipSubmission,
        Commit memory commit
    ) external {
        // Check submission against storage
        bytes32 headerSubmissionHash = keccak256(abi.encode(headerSubmission));
        require(headerSubmissionHash == _headerSubmissionHashes[headerHash]);
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
        delete _headerHeights[headerSubmissionHash];
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
            bytes32 headerSubmissionHash = keccak256(abi.encode(headerSubmission));
            require(headerSubmissionHash == _headerSubmissionHashes[headerHash]);
            // Block must not be finalized yet
            require(_isNotFinalized[headerHash]);

            // Timeout must be expired in order to finalize a block
            require(block.number > SafeMath.add(headerSubmission.blockNumber, _fraudTimeout));

            // Reset storage (height is kept!)
            delete _headerSubmissionHashes[headerHash];
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
            bytes32 headerSubmissionHash = keccak256(abi.encode(headerSubmission));
            require(headerSubmissionHash == _headerSubmissionHashes[headerHash]);
            // Block must not be finalized yet
            require(_isNotFinalized[headerHash]);

            // Previous block must be orphaned
            require(_headerSubmissionHashes[headerSubmission.header.lastBlockID] == 0);

            // Reset storage
            delete _headerSubmissionHashes[headerHash];
            delete _headerHeights[headerSubmissionHash];
            delete _isNotFinalized[headerHash];

            // Return half of bond to pruner
            msg.sender.transfer(SafeMath.div(_bondSize, 2));
        }
    }
}
