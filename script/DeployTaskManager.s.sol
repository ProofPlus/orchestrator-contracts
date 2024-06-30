// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/TaskManager.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract DeployTaskManager is Script {
    IERC20Permit public token = IERC20Permit(0x90193C961A926261B756D1E5bb255e67ff9498A1); // Replace with your token address
    uint256 public amount = 1000 * 10**18; // Replace with your desired amount
    //TODO: implement Ticketing mechanism
    uint256 public taskCost = 10 * 10**18; // Replace with your desired amount

    function run() external {
        vm.startBroadcast();

        TaskManager taskManager = new TaskManager(token, amount, taskCost);

        vm.stopBroadcast();

        console.log("TaskManager deployed at:", address(taskManager));
    }
}
