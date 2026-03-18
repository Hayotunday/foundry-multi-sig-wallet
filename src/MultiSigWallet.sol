// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract MultiSigWallet {
  //// errors
  error MultiSigWallet__OnlyOwnersAreAuthorized();
  error MultiSigWallet__TransactionDoesNotExist();
  error MultiSigWallet__NotEnoughConfirmations();
  error MultiSigWallet__TransactionAlreadyExecuted();
  error MultiSigWallet__InvalidNumOfRequiredConfirmations();
  error MultiSigWallet__OwnersArrayEmpty();
  error MultiSigWallet__OwnerAddressCannotBeBurnAddress();
  error MultiSigWallet__OwnerNotUnique();
  error MultiSigWallet__ExecuteTransactionCallFailed();
  error MultiSigWallet__CallerHasNotConfirmed();
  error MultiSigWallet__CallerAlreadyConfirmed();

  //// data structures
  struct Transaction {
    address to;
    address proposer;
    uint256 value;
    bytes data;
    bool executed;
    bool exists;
    uint256 numConfirmations;
  }

  //// state variables
  uint256 public transactionCount;
  uint256 public immutable numConfirmationsRequired;
  address[] public owners;

  mapping(address => bool) public isOwner;
  mapping(uint256 => Transaction) public transactions;
  mapping(uint256 => mapping(address => bool)) public isConfirmed;

  //// events
  event Deposit(address indexed sender, uint256 amount);
  event SubmitTransaction(address indexed from, uint256 indexed txId);
  event ConfirmTransaction(address indexed from, uint256 indexed txId);
  event RevokeConfirmation(address indexed from, uint256 indexed txId);
  event ExecuteTransaction(address indexed from, uint256 indexed txId);

  //// modifiers
  modifier onlyOwner() {
    if (!isOwner[msg.sender]) revert MultiSigWallet__OnlyOwnersAreAuthorized();
    _;
  }

  modifier txExists(uint256 _txIndex) {
    if (!transactions[_txIndex].exists) {
      revert MultiSigWallet__TransactionDoesNotExist();
    }
    _;
  }

  modifier notExecuted(uint256 _txIndex) {
    if (transactions[_txIndex].executed) {
      revert MultiSigWallet__TransactionAlreadyExecuted();
    }
    _;
  }

  //// functions
  //// constructor
  constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
    uint256 ownersLength = _owners.length;
    if (ownersLength == 0) revert MultiSigWallet__OwnersArrayEmpty();
    if (
      _numConfirmationsRequired == 0 || _numConfirmationsRequired > ownersLength
    ) {
      revert MultiSigWallet__InvalidNumOfRequiredConfirmations();
    }
    for (uint256 i = 0; i < ownersLength; i++) {
      address owner = _owners[i];
      if (owner == address(0)) {
        revert MultiSigWallet__OwnerAddressCannotBeBurnAddress();
      }
      if (isOwner[owner]) revert MultiSigWallet__OwnerNotUnique();
      isOwner[owner] = true;
      owners.push(owner);
    }
    numConfirmationsRequired = _numConfirmationsRequired;
  }

  //// external functions
  receive() external payable {
    emit Deposit(msg.sender, msg.value);
  }

  function submitTransaction(address _to, uint256 _value, bytes calldata _data)
    external
    onlyOwner
    returns (uint256)
  {
    uint256 txIndex = transactionCount;
    transactions[txIndex] = Transaction({
      to: _to,
      proposer: msg.sender,
      value: _value,
      data: _data,
      executed: false,
      exists: true,
      numConfirmations: 0
    });

    emit SubmitTransaction(msg.sender, txIndex);
    _confirmTransaction(txIndex);
    transactionCount++;
    return txIndex;
  }

  function confirmTransaction(uint256 _txIndex)
    external
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    if (isConfirmed[_txIndex][msg.sender]) {
      revert MultiSigWallet__CallerAlreadyConfirmed();
    }
    _confirmTransaction(_txIndex);
  }

  function executeTransaction(uint256 _txIndex)
    external
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    if (transaction.numConfirmations < numConfirmationsRequired) {
      revert MultiSigWallet__NotEnoughConfirmations();
    }
    transaction.executed = true;
    (bool success,) =
      transaction.to.call{value: transaction.value}(transaction.data);
    if (!success) revert MultiSigWallet__ExecuteTransactionCallFailed();
    emit ExecuteTransaction(msg.sender, _txIndex);
  }

  function revokeConfirmation(uint256 _txIndex)
    external
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    if (!isConfirmed[_txIndex][msg.sender]) {
      revert MultiSigWallet__CallerHasNotConfirmed();
    }
    isConfirmed[_txIndex][msg.sender] = false;
    transactions[_txIndex].numConfirmations--;
    emit RevokeConfirmation(msg.sender, _txIndex);
  }

  //// internal functions
  function _confirmTransaction(uint256 _txIndex) internal {
    isConfirmed[_txIndex][msg.sender] = true;
    transactions[_txIndex].numConfirmations++;
    emit ConfirmTransaction(msg.sender, _txIndex);
  }

  //// getter functions
  function getOwners() external view returns (address[] memory) {
    return owners;
  }

  function getNumConfirmationsRequired() external view returns (uint256) {
    return numConfirmationsRequired;
  }

  function getTransactionCount() external view returns (uint256) {
    return transactionCount;
  }
}
