// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.6.0 <8.0.0;
pragma experimental ABIEncoderV2;

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
    uint8 signaturesCount;
    CommitSig[] signatures;
}

/// @notice Bare minimim block data. Only contains the block header and commit.
struct LightBlock {
    Header header;
    Commit lastCommit;
}

library Serializer {
    using Serializer for Header;
    using Serializer for Signature;
    using Serializer for CommitSig;
    using Serializer for Commit;
    using Serializer for LightBlock;

    ////////////////////////////////////
    // Objects
    ////////////////////////////////////

    function serialize(Header memory obj) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                obj.height,
                obj.timestamp,
                obj.lastBlockID,
                obj.lastCommitRoot,
                obj.consensusRoot,
                obj.stateCommitment,
                obj.availableDataRoot,
                obj.proposerAddress
            );
    }

    function serialize(Signature memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.r, obj.vs);
    }

    function serialize(CommitSig memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.blockIDFlag, obj.validatorAddress, obj.timestamp, obj.signature.serialize());
    }

    function serialize(Commit memory obj) internal pure returns (bytes memory) {
        // TODO serialize sigs
        return abi.encodePacked(obj.height, obj.round, obj.blockID, obj.signaturesCount);
    }

    function serialize(LightBlock memory obj) internal pure returns (bytes memory) {
        return abi.encodePacked(obj.header.serialize(), obj.lastCommit.serialize());
    }
}
