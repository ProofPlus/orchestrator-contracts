// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TaskManager} from "contracts/TaskManager.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProofPlusToken} from "contracts/ProofPlusToken.sol";


import {RiscZeroCheats} from "risc0/RiscZeroCheats.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

contract DeployInitialTaskManager is RiscZeroCheats, Test {
    TaskManager taskManager;
    IRiscZeroVerifier verifier;
    ProofPlusToken token;

    uint256 public registerThreshold = 10 ether; // Replace with your desired amount
    uint256 slotDuration = 10; // 10 blocks
    uint256 public initialSupply = 1000000 * 10 ** 18; // 1 million tokens

    function setUp() external {
        vm.startBroadcast();

        IRiscZeroVerifier verifier = deployRiscZeroVerifier();

        // Deploy the TaskManager implementation contract
        taskManager = new TaskManager();

        token = new ProofPlusToken(initialSupply);

        //NOTE: if initialization parameters change, modify them here as well
        bytes memory data = abi.encodeCall(taskManager.initialize, (address(verifier), address(token), registerThreshold, slotDuration));
        
        address proxyAddress = address(new ERC1967Proxy(address(taskManager), data));

        vm.stopBroadcast();

        console2.log("TaskManager deployed at:", address(taskManager));
        console2.log("UUPS deployed at:", address(proxyAddress));
    }

    function test() external {
        address mockProver = vm.addr(1);
        //TODO: approve needed?
        token.transfer(mockProver, 1 ether);

        vm.startPrank(mockProver);
        taskManager.register("http://127.0.0.1:3000/proof");

        //attempt to buy ticket for next slot. Since there is only one bidder, we are guaranteed to win
        taskManager.bid(1 ether);
        vm.stopPrank();

        address mockUser = vm.addr(2);
        token.transfer(mockUser, 1 ether);
        vm.startPrank(mockUser);
        //TODO: how much should a task cost?
        bytes32 taskId = taskManager.requestTask();
        vm.stopPrank();

        vm.startPrank(mockProver);

        string[] memory imageRunnerInput = new string[](3);
        uint256 i = 0;
        imageRunnerInput[i++] = "cargo";
        imageRunnerInput[i++] = "run";
        imageRunnerInput[i++] = "--release";
        (publicInputs, imageId, proof) =
            abi.decode(vm.ffi(imageRunnerInput), (bytes, bytes32, bytes));

        // NOTE: due to Risc0 requirements the hash passed to the on-chain verifier must be sha256 instead of keccak256    
        bytes32 publicInputHash = sha256(publicInputs); 
        bytes32 proofHash = keccak256(proof);

        taskManager.finalizeTask(taskId, imageId, publicInputHash, proofHash);
        //TODO: ensure prover has increased token balance
    }
}
