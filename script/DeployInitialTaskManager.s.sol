// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TaskManager} from "contracts/TaskManager.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

import {console} from "forge-std/console.sol";

contract DeployInitialTaskManager is Script {
    address public token = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // Replace with your token address
    address verifier = address(0); // Replace with your verifier address
    uint256 public registerThreshold = 10 ether; // Replace with your desired amount
    uint256 slotDuration = 10; // 10 blocks

    function run() external {
        vm.startBroadcast();

        // Deploy the TaskManager implementation contract
        TaskManager taskManager = new TaskManager();

        //NOTE: if initialization parameters change, modify them here as well
        bytes memory data = abi.encodeCall(taskManager.initialize, (verifier, token, registerThreshold, slotDuration));
        
        address proxyAddress = address(new ERC1967Proxy(address(taskManager), data));

        vm.stopBroadcast();

        console.logString("TaskManager deployed at:");
        console.logAddress(address(taskManager));
        console.logString("UUPS deployed at:");
        console.logAddress(address(proxyAddress));
    }
}
