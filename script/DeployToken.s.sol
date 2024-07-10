// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ProofPlusToken} from "contracts/ProofPlusToken.sol";

import {console} from "forge-std/console.sol";

contract DeployToken is Script {
    uint256 public initialSupply = 1000000 * 10 ** 18; // 1 million tokens

    function run() external {
        vm.startBroadcast();

        ProofPlusToken token = new ProofPlusToken(initialSupply);

        vm.stopBroadcast();

        console.logString("Proof Plus Token deployed at:");
        console.logAddress(address(token));
    }
}
