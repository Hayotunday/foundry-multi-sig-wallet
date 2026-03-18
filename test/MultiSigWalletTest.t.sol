// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";
import {DeployMultiSigWallet} from "script/DeployMultiSigWallet.s.sol";

contract MultiSigWalletTest is Test {
  MultiSigWallet public multisig;
  DeployMultiSigWallet public deployer;
  address public immutable USER1 = makeAddr("USER1");
  address public immutable USER2 = makeAddr("USER2");
  address public immutable USER3 = makeAddr("USER3");
  address public immutable RECEIVER = makeAddr("RECEIVER");
  address public constant BURN_ADDRESS = address(0);
  address[] public owners = [USER1, USER2, USER3];
  uint256 public constant NUM_REQUIRED_CONFIRMATIONS = 2;

  function setUp() public {
    deployer = new DeployMultiSigWallet();
    multisig = deployer.run(owners, NUM_REQUIRED_CONFIRMATIONS);
  }

  function testReceive() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    vm.stopPrank();
    assertEq(address(multisig).balance, amount);
  }

  function testSubmitTransaction() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    (
      address to,
      address proposer,
      uint256 value,
      bytes memory data,
      bool executed,
      bool exists,
      uint256 numConfirmations
    ) = multisig.transactions(txId);
    assertEq(to, RECEIVER);
    assertEq(proposer, USER1);
    assertEq(value, amount);
    assertEq(data, "");
    assertEq(executed, false);
    assertEq(exists, true);
    assertEq(numConfirmations, 1);
  }

  function testConfirmTransaction() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.confirmTransaction(txId);
    vm.stopPrank();

    (,,,,, bool exists, uint256 numConfirmations) = multisig.transactions(txId);
    assertEq(exists, true);
    assertEq(numConfirmations, 2);
    assertEq(multisig.isConfirmed(txId, USER2), true);
  }

  function testRevokeConfirmation() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.confirmTransaction(txId);
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.revokeConfirmation(txId);
    vm.stopPrank();

    (,,,,, bool exists, uint256 numConfirmations) = multisig.transactions(txId);
    assertEq(exists, true);
    assertEq(numConfirmations, 1);
    assertEq(multisig.isConfirmed(txId, USER2), false);
  }

  function testExecuteTransaction() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.confirmTransaction(txId);
    vm.stopPrank();

    vm.startPrank(USER3);
    multisig.executeTransaction(txId);
    vm.stopPrank();

    (,,,, bool executed, bool exists, uint256 numConfirmations) = multisig.transactions(txId);
    assertEq(executed, true);
    assertEq(exists, true);
    assertEq(numConfirmations, 2);
    assertEq(address(RECEIVER).balance, amount);
    assertEq(address(multisig).balance, 0);
  }

  function testGetOwners() public view {
    address[] memory authorized = multisig.getOwners();
    assertEq(authorized.length, 3);
    assertEq(keccak256(abi.encodePacked(authorized)), keccak256(abi.encodePacked(owners)));
  }

  function testGetNumConfirmationsRequired() public view {
    uint256 numConfirmationsRequired = multisig.getNumConfirmationsRequired();
    assertEq(numConfirmationsRequired, NUM_REQUIRED_CONFIRMATIONS);
  }

  function testGetTransactionCount() public view {
    uint256 transactionCount = multisig.getTransactionCount();
    assertEq(transactionCount, 0);
  }

  function testOnlyOwnersAreAuthorized() public {
    uint256 amount = 1 ether;
    vm.startPrank(RECEIVER);
    vm.deal(RECEIVER, amount);
    payable(address(multisig)).transfer(amount);

    vm.expectRevert(MultiSigWallet.MultiSigWallet__OnlyOwnersAreAuthorized.selector);
    multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();
  }

  function testTransactionDoesNotExist() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionDoesNotExist.selector);
    multisig.confirmTransaction(10);
    vm.stopPrank();
  }

  function testNotEnoughConfirmations() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER3);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__NotEnoughConfirmations.selector);
    multisig.executeTransaction(txId);
    vm.stopPrank();
  }

  function testTransactionAlreadyExecuted() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.confirmTransaction(txId);
    vm.stopPrank();

    vm.startPrank(USER3);
    multisig.executeTransaction(txId);
    vm.stopPrank();

    vm.startPrank(USER1);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyExecuted.selector);
    multisig.executeTransaction(txId);
    vm.stopPrank();
  }

  function testInvalidNumOfRequiredConfirmations() public {
    vm.expectRevert(MultiSigWallet.MultiSigWallet__InvalidNumOfRequiredConfirmations.selector);
    new MultiSigWallet(owners, 4);
  }

  function testOwnersArrayEmpty() public {
    vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnersArrayEmpty.selector);
    new MultiSigWallet(new address[](0), 1);
  }

  function testOwnerAddressCannotBeBurnAddress() public {
    address[] memory _owners = new address[](3);
    _owners[0] = BURN_ADDRESS;
    _owners[1] = USER1;
    _owners[2] = USER2;

    vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnerAddressCannotBeBurnAddress.selector);
    new MultiSigWallet(_owners, 1);
  }

  function testOwnerNotUnique() public {
    address[] memory _owners = new address[](3);
    _owners[0] = USER1;
    _owners[1] = USER1;
    _owners[2] = USER2;

    vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnerNotUnique.selector);
    new MultiSigWallet(_owners, 1);
  }

  function testExecuteTransactionCallFailed() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, 2 ether, "");
    vm.stopPrank();

    vm.startPrank(USER2);
    multisig.confirmTransaction(txId);
    vm.stopPrank();

    vm.startPrank(USER3);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__ExecuteTransactionCallFailed.selector);
    multisig.executeTransaction(txId);
    vm.stopPrank();
  }

  function testCallerHasNotConfirmed() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER3);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerHasNotConfirmed.selector);
    multisig.revokeConfirmation(txId);
    vm.stopPrank();
  }

  function testCallerAlreadyConfirmed() public {
    uint256 amount = 1 ether;
    vm.startPrank(USER1);
    vm.deal(USER1, amount);
    payable(address(multisig)).transfer(amount);
    uint256 txId = multisig.submitTransaction(RECEIVER, amount, "");
    vm.stopPrank();

    vm.startPrank(USER1);
    vm.expectRevert(MultiSigWallet.MultiSigWallet__CallerAlreadyConfirmed.selector);
    multisig.confirmTransaction(txId);
    vm.stopPrank();
  }
}

// error MultiSigWallet__OnlyOwnersAreAuthorized();
// error MultiSigWallet__TransactionDoesNotExist();
// error MultiSigWallet__NotEnoughConfirmations();
// error MultiSigWallet__TransactionAlreadyExecuted();
// error MultiSigWallet__InvalidNumOfRequiredConfirmations();
// error MultiSigWallet__OwnersArrayEmpty();
// error MultiSigWallet__OwnerAddressCannotBeBurnAddress();
// error MultiSigWallet__OwnerNotUnique();
// error MultiSigWallet__ExecuteTransactionCallFailed();
// error MultiSigWallet__CallerHasNotConfirmed();
// error MultiSigWallet__CallerAlreadyConfirmed();
