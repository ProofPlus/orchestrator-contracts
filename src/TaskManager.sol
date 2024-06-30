// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TaskManager {
    using SafeERC20 for IERC20;

    IERC20Permit public token;
    uint256 public registerThreshold;
    uint256 public taskCost;
    address[] public registeredProvers;
    mapping(address => ReportedCapability) public capabilities;
    mapping(bytes32 => TaskStatus) public tasks;

    struct ReportedCapability {
        string endpoint;
        uint256 speed;
    }

    struct TaskStatus {
        address requester;
        address prover;
        uint256 reward;
    }

    event TaskRequested(bytes32 taskId, address requester, address prover, string endpoint);

    constructor(IERC20Permit _token, uint256 _registerThreshold, uint256 _taskCost) {
        token = _token;
        registerThreshold = _registerThreshold;
        taskCost = _taskCost;
    }

    function register(
        ReportedCapability calldata capability,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        token.permit(msg.sender, address(this), registerThreshold, deadline, v, r, s);
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), registerThreshold);
        capabilities[msg.sender] = capability;
        registeredProvers.push(msg.sender);
    }

    function requestTask(
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(registeredProvers.length > 0, "No registered provers");

        // Randomly select a prover
        address prover = registeredProvers[uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % registeredProvers.length];

        // Use permit to approve token transfer for task cost
        token.permit(msg.sender, address(this), taskCost, deadline, v, r, s);

        // Transfer tokens from the sender to the contract using safeTransferFrom
        IERC20(address(token)).safeTransferFrom(msg.sender, address(this), taskCost);

        // Create task status
        TaskStatus memory task = TaskStatus({
            requester: msg.sender,
            prover: prover,
            reward: taskCost
        });

        // Generate taskId from TaskStatus
        bytes32 taskId = keccak256(abi.encode(task));

        // Store the task details in storage
        tasks[taskId] = task;

        // Emit event with the prover's endpoint
        emit TaskRequested(taskId, msg.sender, prover, capabilities[prover].endpoint);
    }
}
