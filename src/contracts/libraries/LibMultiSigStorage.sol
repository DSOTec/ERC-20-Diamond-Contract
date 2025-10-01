// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibMultiSigStorage {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.standard.multisig.storage");

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    struct MultiSigStorage {
        address[] signatories;
        mapping(address => bool) isSigner;
        uint256 threshold;
        Transaction[] transactions;
        // txId => signer => confirmed
        mapping(uint256 => mapping(address => bool)) confirmations;
    }

    function multiSigStorage() internal pure returns (MultiSigStorage storage ms) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }
}
