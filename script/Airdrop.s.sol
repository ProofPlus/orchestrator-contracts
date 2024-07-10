// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Airdrop is Script {
    IERC20 public token = IERC20(0x5FbDB2315678afecb367f032d93F642f64180aa3); // in case of Anvil localhost deployment
    uint256 public amountPerRecipient = 100 * 10 ** 18; // Amount per recipient

    function run() external {
        vm.startBroadcast();

        for (uint256 i = 0; i < 100; i++) {
            string memory recipient = vm.readLine("recipients.txt");
            address recipientAddress = vm.parseAddress(recipient);
            token.transfer(recipientAddress, amountPerRecipient);
        }

        vm.stopBroadcast();
    }
}
