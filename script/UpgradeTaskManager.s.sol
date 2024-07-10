// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {TaskManager} from "contracts/TaskManager.sol";

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {console} from "forge-std/console.sol";

contract UpgradeTaskManager is Script {
    address public proxyAddress = address(0); // Replace with your proxy address

    address public token = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Replace with your token address
    address public verifier = address(0); // Replace with your verifier address
    uint256 public registerThreshold = 10 ether; // Replace with your desired amount
    uint256 public slotDuration = 10; // 10 blocks

    function run() external {
        vm.startBroadcast();

        TaskManager newTaskManagerImplementation = new TaskManager();

        bytes memory data = abi.encodeCall(newTaskManagerImplementation.initialize, (verifier, token, registerThreshold, slotDuration));
        
        UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(address(newTaskManagerImplementation), data);

        vm.stopBroadcast();

        console.logString("TaskManager upgraded to:");
        console.logAddress(address(newTaskManagerImplementation));
    }
}
