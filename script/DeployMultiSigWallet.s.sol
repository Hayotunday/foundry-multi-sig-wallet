// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
  MultiSigWallet public multisig;

  function run(address[] memory _owners, uint256 numRequiredConfirmations) external returns (MultiSigWallet) {
    vm.startBroadcast();
    multisig = new MultiSigWallet(_owners, numRequiredConfirmations);
    vm.stopBroadcast();
    return multisig;
  }
}
