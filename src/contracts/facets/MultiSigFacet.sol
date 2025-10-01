// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/LibMultiSigStorage.sol";
import "../libraries/LibDiamond.sol";

/**
 * @title MultiSigFacet
 * @notice Multi-signature wallet functionality for the Diamond
 * @dev All signatories and transactions are stored in Diamond Storage
 */
contract MultiSigFacet {
    event SignatoryAdded(address indexed signatory);
    event SignatoryRemoved(address indexed signatory);
    event ThresholdChanged(uint256 newThreshold);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed txId, address indexed signer);
    event TransactionRevoked(uint256 indexed txId, address indexed signer);
    event TransactionExecuted(uint256 indexed txId);

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlySigner() {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(ms.isSigner[msg.sender], "MultiSig: not a signer");
        _;
    }

    modifier txExists(uint256 txId) {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(txId < ms.transactions.length, "MultiSig: tx does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(!ms.transactions[txId].executed, "MultiSig: tx already executed");
        _;
    }

    /**
     * @notice Add a new signatory
     * @param signatory Address to add as signatory
     */
    function addSignatory(address signatory) external onlyOwner {
        require(signatory != address(0), "MultiSig: zero address");
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(!ms.isSigner[signatory], "MultiSig: already a signer");

        ms.signatories.push(signatory);
        ms.isSigner[signatory] = true;
        emit SignatoryAdded(signatory);
    }

    /**
     * @notice Remove a signatory
     * @param signatory Address to remove
     */
    function removeSignatory(address signatory) external onlyOwner {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(ms.isSigner[signatory], "MultiSig: not a signer");
        require(ms.signatories.length > ms.threshold, "MultiSig: cannot remove, would break threshold");

        ms.isSigner[signatory] = false;
        
        // Remove from array
        for (uint256 i = 0; i < ms.signatories.length; i++) {
            if (ms.signatories[i] == signatory) {
                ms.signatories[i] = ms.signatories[ms.signatories.length - 1];
                ms.signatories.pop();
                break;
            }
        }
        emit SignatoryRemoved(signatory);
    }

    /**
     * @notice Set the threshold for transaction execution
     * @param _threshold Minimum number of confirmations required
     */
    function setThreshold(uint256 _threshold) external onlyOwner {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(_threshold > 0, "MultiSig: threshold must be > 0");
        require(_threshold <= ms.signatories.length, "MultiSig: threshold too high");

        ms.threshold = _threshold;
        emit ThresholdChanged(_threshold);
    }

    /**
     * @notice Submit a new transaction
     * @param to Destination address
     * @param value ETH value to send
     * @param data Call data
     * @return txId The ID of the submitted transaction
     */
    function submitTransaction(address to, uint256 value, bytes calldata data) 
        external 
        onlySigner 
        returns (uint256 txId) 
    {
        require(to != address(0), "MultiSig: zero address");
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();

        txId = ms.transactions.length;
        ms.transactions.push(LibMultiSigStorage.Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        }));

        emit TransactionSubmitted(txId, to, value, data);
    }

    /**
     * @notice Confirm a transaction
     * @param txId Transaction ID
     */
    function confirmTransaction(uint256 txId) 
        external 
        onlySigner 
        txExists(txId) 
        notExecuted(txId) 
    {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(!ms.confirmations[txId][msg.sender], "MultiSig: already confirmed");

        ms.confirmations[txId][msg.sender] = true;
        ms.transactions[txId].confirmations += 1;

        emit TransactionConfirmed(txId, msg.sender);
    }

    /**
     * @notice Revoke a confirmation
     * @param txId Transaction ID
     */
    function revokeConfirmation(uint256 txId) 
        external 
        onlySigner 
        txExists(txId) 
        notExecuted(txId) 
    {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        require(ms.confirmations[txId][msg.sender], "MultiSig: not confirmed");

        ms.confirmations[txId][msg.sender] = false;
        ms.transactions[txId].confirmations -= 1;

        emit TransactionRevoked(txId, msg.sender);
    }

    /**
     * @notice Execute a transaction if threshold is met
     * @param txId Transaction ID
     */
    function executeTransaction(uint256 txId) 
        external 
        onlySigner 
        txExists(txId) 
        notExecuted(txId) 
    {
        LibMultiSigStorage.MultiSigStorage storage ms = LibMultiSigStorage.multiSigStorage();
        LibMultiSigStorage.Transaction storage txn = ms.transactions[txId];
        
        require(txn.confirmations >= ms.threshold, "MultiSig: insufficient confirmations");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "MultiSig: execution failed");

        emit TransactionExecuted(txId);
    }

    /**
     * @notice Get list of all signatories
     * @return Array of signatory addresses
     */
    function getSignatories() external view returns (address[] memory) {
        return LibMultiSigStorage.multiSigStorage().signatories;
    }

    /**
     * @notice Get current threshold
     * @return The threshold value
     */
    function getThreshold() external view returns (uint256) {
        return LibMultiSigStorage.multiSigStorage().threshold;
    }

    /**
     * @notice Check if an address is a signer
     * @param account Address to check
     * @return True if the address is a signer
     */
    function isSigner(address account) external view returns (bool) {
        return LibMultiSigStorage.multiSigStorage().isSigner[account];
    }

    /**
     * @notice Get transaction details
     * @param txId Transaction ID
     * @return to Destination address
     * @return value ETH value
     * @return data Call data
     * @return executed Whether the transaction has been executed
     * @return confirmations Number of confirmations
     */
    function getTransaction(uint256 txId) 
        external 
        view 
        txExists(txId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        ) 
    {
        LibMultiSigStorage.Transaction storage txn = LibMultiSigStorage.multiSigStorage().transactions[txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }

    /**
     * @notice Get total number of transactions
     * @return The transaction count
     */
    function getTransactionCount() external view returns (uint256) {
        return LibMultiSigStorage.multiSigStorage().transactions.length;
    }

    /**
     * @notice Check if a signer has confirmed a transaction
     * @param txId Transaction ID
     * @param signer Signer address
     * @return True if confirmed
     */
    function hasConfirmed(uint256 txId, address signer) 
        external 
        view 
        txExists(txId)
        returns (bool) 
    {
        return LibMultiSigStorage.multiSigStorage().confirmations[txId][signer];
    }
}
