// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

contract MultiSigBank {

    uint constant public MAX_OWNER_COUNT = 50;

    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);

    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint public required;
    uint public transactionCount;

    struct Transaction {
        bytes32 description;    // 描述
        uint48 createTime;     // 提出时间
        address destination;
        uint value;
        bytes data;
        address submitter;      // 提交人，0代表议案已废弃
        bool executed;
    }

    modifier onlyWallet() {
        require(msg.sender == address(this), "onlyWallet");
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner], "ownerDoesNotExist");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "ownerExists");
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0), "transactionExists");
        _;
    }

    modifier confirmed(uint transactionId, address owner) {
        require(confirmations[transactionId][owner], "confirmed");
        _;
    }

    modifier notConfirmed(uint transactionId, address owner) {
        require(!confirmations[transactionId][owner], "notConfirmed");
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed, "notExecuted");
        _;
    }

    modifier notDiscarded(uint transactionId) {
        require(transactions[transactionId].submitter != address(0), "discarded");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "notNull");
        _;
    }

    modifier validRequirement(uint ownerCount, uint _required) {
        require(
            ownerCount <= MAX_OWNER_COUNT &&
            _required <= ownerCount &&
            _required > 0 &&
            ownerCount > 0, "validRequirement"
        );
        _;
    }

    /// @dev Fallback function allows to deposit ether.
    receive() external payable {
        if (msg.value > 0)
            emit Deposit(msg.sender, msg.value);
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor (address[] memory _owners, uint _required){
        for (uint i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "0");
            require(!isOwner[_owners[i]], "owner ready");
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of new owner.
    function addOwner(address owner) public onlyWallet
    ownerDoesNotExist(owner) notNull(owner) validRequirement(owners.length + 1, required) {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner.
    function removeOwner(address owner) public onlyWallet ownerExists(owner) {
        isOwner[owner] = false;
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        if (required > owners.length)
            changeRequirement(owners.length);
        emit OwnerRemoval(owner);
    }

    /// @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner to be replaced.
    /// @param owner Address of new owner.
    function replaceOwner(address owner, address newOwner) public onlyWallet ownerExists(owner) ownerDoesNotExist(newOwner) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        }

        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
    /// @param _required Number of required confirmations.
    function changeRequirement(uint _required) public onlyWallet validRequirement(owners.length, _required) {
        required = _required;
        emit RequirementChange(_required);
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @param description A brief description of this transaction, less than 32 bytes.
    /// @return transactionId transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data, bytes32 description) public returns (uint transactionId){
        transactionId = addTransaction(destination, value, data, description);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public ownerExists(msg.sender) transactionExists(transactionId) notDiscarded(transactionId) notConfirmed(transactionId, msg.sender) {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        // have to manually execute considerring TRON's energy problem
        // executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public ownerExists(msg.sender) confirmed(transactionId, msg.sender) notExecuted(transactionId) {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public notDiscarded(transactionId) notExecuted(transactionId) {
        if (isConfirmed(transactionId)) {
            Transaction storage transaction = transactions[transactionId];
            transaction.executed = true;
            (bool success, bytes memory returndata) = transaction.destination.call{value: transaction.value}(transaction.data);
            Address.verifyCallResult(success, returndata);
            // if (success) {
            //     emit Execution(transactionId);
            // } else {
            //     emit ExecutionFailure(transactionId);
            //     transaction.executed = false;
            // }
            // Address.functionCallWithValue(transaction.destination, transaction.data, transaction.value);
            // If function call failed, it will revert, never come here.
            emit Execution(transactionId);
        }
    }

    // TODO: 提案发起人有权废弃一个提案
    function discardTransaction(uint transactionId) public notExecuted(transactionId) {
        Transaction storage transaction = transactions[transactionId];
        require(msg.sender == transaction.submitter, "not submitter");
        transaction.submitter = address(0);
    }

    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) public view returns (bool){
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
        return false;
    }

    /*
     * Internal functions
     */
    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @param description A brief description of this transaction, less than 32 bytes.
    /// @return transactionId transaction ID.
    function addTransaction(address destination, uint value, bytes memory data, bytes32 description) internal notNull(destination) returns (uint transactionId){
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            description: description,
            createTime: uint48(block.timestamp),
            destination: destination,
            value: value,
            data: data,
            submitter: msg.sender,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }

    /*
     * Web3 call functions
     */
    /// @dev Returns number of confirmations of a transaction.
    /// @param transactionId Transaction ID.
    /// @return count of confirmations.
    function getConfirmationCount(uint transactionId)
    public
    view
    returns (uint count)
    {
        for (uint i = 0; i < owners.length; i++)
            if (confirmations[transactionId][owners[i]])
                count += 1;
    }

    /// @dev Returns total number of transactions after filers are applied.
    /// @param pending Include pending transactions.
    /// @param executed Include executed transactions.
    /// @return count Total number of transactions after filters are applied.
    function getTransactionCount(bool pending, bool executed)
    public
    view
    returns (uint count)
    {
        for (uint i = 0; i < transactionCount; i++) {
            if (transactions[i].submitter == address(0))    // discarded
                continue;
            if (pending && !transactions[i].executed
            || executed && transactions[i].executed)
                count += 1;
        }
    }

    /// @dev Returns list of owners.
    /// @return List of owner addresses.
    function getOwners() public view returns (address[] memory){
        return owners;
    }

    /// @dev Returns array with owner addresses, which confirmed transaction.
    /// @param transactionId Transaction ID.
    /// @return _confirmations array of owner addresses.
    function getConfirmations(uint transactionId) public view returns (address[] memory _confirmations){
        address[] memory confirmationsTemp = new address[](owners.length);
        uint count = 0;
        uint i;
        for (i = 0; i < owners.length; i++)
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i = 0; i < count; i++)
            _confirmations[i] = confirmationsTemp[i];
    }

    /// @dev Returns list of transaction IDs in defined range.
    /// @param from Index start position of transaction array.
    /// @param to Index end position of transaction array.
    /// @param pending Include pending transactions.
    /// @param executed Include executed transactions.
    /// @return _transactionIds array of transaction IDs.
    function getTransactionIds(uint from, uint to, bool pending, bool executed) public view returns (uint[] memory _transactionIds){
        uint[] memory transactionIdsTemp = new uint[](transactionCount);
        uint count = 0;
        uint i;
        for (i = 0; i < transactionCount; i++) {
            if (transactions[i].submitter == address(0))    // discarded
                continue;
            if (pending && !transactions[i].executed
            || executed && transactions[i].executed)
            {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        }
        _transactionIds = new uint[](to - from);
        for (i = from; i < to; i++)
            _transactionIds[i - from] = transactionIdsTemp[i];
    }

    /// @notice 获取最近的提案
    function getTransactions(uint count, address account) public view returns (
        Transaction[] memory _transactions,
        bool[] memory _isAccountConfirms,
        bool[] memory _confirms,
        uint[] memory _ids
    ){
        if (count > transactionCount) count = transactionCount;

        _transactions = new Transaction[](count);
        _isAccountConfirms = new bool[](count);
        _confirms = new bool[](count);
        _ids = new uint[](count);

        for (uint i = 0; i < count; i++) {
            uint transactionId = transactionCount - 1 - i;
            _transactions[i] = transactions[transactionId];
            _isAccountConfirms[i] = confirmations[transactionId][account];
            _confirms[i] = isConfirmed(transactionId);
            _ids[i] = transactionId;
        }
    }
}
