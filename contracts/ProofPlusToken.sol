pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ProofPlusToken is ERC20Permit {
    constructor(uint256 initialSupply) ERC20Permit("Proof Plus Token") ERC20("Proof Plus Token", "PPT") {
        _mint(msg.sender, initialSupply);
    }
}
