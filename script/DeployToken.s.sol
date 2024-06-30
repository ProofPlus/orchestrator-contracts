// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ProofPlusToken is ERC20Permit {
    constructor(uint256 initialSupply) ERC20Permit("Proof Plus Token") ERC20("Proof Plus Token", "PPT") {
        _mint(msg.sender, initialSupply);
    }
}

contract DeployToken is Script {
    uint256 public initialSupply = 1000000 * 10**18; // 1 million tokens

    function run() external {
        vm.startBroadcast();

        ProofPlusToken token = new ProofPlusToken(initialSupply);

        vm.stopBroadcast();

        console.log("Proof Plus Token deployed at:", address(token));
    }
}
