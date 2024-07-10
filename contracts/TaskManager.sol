// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

contract TaskManager is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public token;
    uint256 public registerThreshold;
    uint256 public slotDuration;

    mapping(address => string) public endpoints;
    mapping(bytes32 => TaskStatus) public tasks;

    IRiscZeroVerifier public verifier;

    struct TaskStatus {
        address requester;
        address prover;
        uint256 reward;
        bytes32 imageId;
        bytes32 publicInputsHash;
        bytes32 proofHash;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 slot;
    }

    Bid public highestBid;
    mapping(uint256 => address) public slotToProver;

    error NotRegistered(address sender);
    error BidTooLow(uint256 amount, uint256 requiredAmount);
    error HigherBidExists(uint256 amount, uint256 highestBid);
    error InvalidTaskId(bytes32 taskId);
    error TaskAlreadyClaimed(bytes32 taskId);
    error NotAssignedProver(address prover, address sender);

    event TaskRequested(bytes32 taskId, address requester, address prover, string endpoint);
    event BidPlaced(address bidder, uint256 amount, uint256 slot);
    event TicketIssued(uint256 slot, address prover);
    event TaskFinalized(bytes32 taskId, bytes32 imageId, bytes32 publicInputsHash, bytes32 proofHash);
    event ProverSlashed(address prover, bytes32 taskId, bytes32 imageId);


    modifier onlyRegisteredProver() {
        if (bytes(endpoints[msg.sender]).length == 0) revert NotRegistered(msg.sender);
        _;
    }

    function initialize(address _verifier, address _token, uint256 _registerThreshold, uint256 _slotDuration) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        verifier = IRiscZeroVerifier(_verifier);
        token = _token;
        registerThreshold = _registerThreshold;
        slotDuration = _slotDuration;
        highestBid = Bid(address(0), 0, 0);
    }

    /// The register mechanism is needed by the protocol in order to have a larger amount of staked collateral that can be slashed in case of malicious behaviour from the prover
    function register(string calldata endpoint) external {
        _register(endpoint);
    }

    function registerPermit(string calldata endpoint, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        IERC20Permit(token).permit(msg.sender, address(this), registerThreshold, deadline, v, r, s);
        _register(endpoint);
    }

    function _register(string calldata endpoint) internal {
        require(msg.sender != address(0), "Invalid address");
        endpoints[msg.sender] = endpoint;
        IERC20(token).safeTransferFrom(msg.sender, address(this), registerThreshold);
    }

    function requestTaskPermit(uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (bytes32 taskId){
        IERC20Permit(token).permit(msg.sender, address(this), highestBid.amount, deadline, v, r, s);
        taskId = _requestTask();
    }

    /// used by Protocol users to request proving tasks
    function requestTask() external returns (bytes32 taskId) {
        taskId = _requestTask();
    }

    function _requestTask() internal returns (bytes32 taskId) {
        uint256 currentSlot = block.number / slotDuration;
        address prover = slotToProver[currentSlot];
        
        require(prover != address(0), "No prover for current slot");

        TaskStatus memory task = TaskStatus({
            requester: msg.sender,
            prover: prover,
            reward: highestBid.amount,
            imageId: bytes32(0),
            publicInputsHash: bytes32(0),
            proofHash: bytes32(0)
        });

        taskId = keccak256(abi.encode(task));
        tasks[taskId] = task;

        IERC20(token).safeTransferFrom(msg.sender, address(this), highestBid.amount);

        emit TaskRequested(taskId, msg.sender, prover, endpoints[prover]);
    }

    /// on-chain task finalization exposes the publicInputHash, however it does not expose the proof itself.
    /// if the proof or the publicInputsHash were proven wrong by a ZKP, the prover will get slashed
    function finalizeTask(bytes32 taskId, bytes32 imageId, bytes32 publicInputsHash, bytes32 proofHash) external {
        TaskStatus storage task = tasks[taskId];

        if (task.requester == address(0)) revert InvalidTaskId(taskId);
        if (task.reward == 0) revert TaskAlreadyClaimed(taskId);

        if (task.prover != msg.sender) revert NotAssignedProver(task.prover, msg.sender);

        task.imageId = imageId;
        task.publicInputsHash = publicInputsHash;
        task.proofHash = proofHash;
        task.reward = 0;

        IERC20(token).safeTransfer(msg.sender, task.reward);

        emit TaskFinalized(taskId, imageId, publicInputsHash, proofHash);
    }

    function bid(uint256 amount) external onlyRegisteredProver {

        uint256 currentSlot = (block.number / slotDuration) + 1;

        // Checks
        if (highestBid.slot < currentSlot) {
            // Effects
            if (highestBid.bidder != address(0)) {
                slotToProver[highestBid.slot] = highestBid.bidder;
                emit TicketIssued(highestBid.slot, highestBid.bidder);
            }
            highestBid = Bid(address(0), 0, currentSlot);
        }

        if (amount <= highestBid.amount) revert HigherBidExists(amount, highestBid.amount);

        // Interactions
        if (highestBid.bidder != address(0)) {
            IERC20(token).safeTransfer(highestBid.bidder, highestBid.amount);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Effects
        highestBid = Bid(msg.sender, amount, currentSlot);
        emit BidPlaced(msg.sender, amount, currentSlot);
    }


    function slash(bytes32 taskId, bytes32 publicInputsHash, bytes calldata proof) external {
        TaskStatus storage task = tasks[taskId];

        // veriifcation will revert on failure and only continue on success
        verifier.verify(proof, task.imageId, publicInputsHash);

        // a valid ZKP was supplied for the correct imageId, however the proofHash or inputsHash does not correspond to the ones commited to
        if(publicInputsHash != task.publicInputsHash || keccak256(abi.encode(proof)) != task.proofHash) {
            // slash the prover, removing them from the registered list
            delete endpoints[task.prover];

            // award the caller (acting as slasher) by the whole stake of the malicious prover
            IERC20(token).safeTransfer(msg.sender, task.reward + registerThreshold);

            emit ProverSlashed(task.prover, taskId, task.imageId);

        }

    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
