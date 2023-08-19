// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;  //Do not change the solidity version as it negativly impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

abstract contract ReentrancyGuard {
    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }
}

contract Staker is ReentrancyGuard {

  mapping(address => uint256) public balances;
  uint256 public constant threshold = 1 ether;
  uint256 public deadline = block.timestamp + 30 seconds;
  event Stake(address, uint256);
  bool internal openForWithdraw = false;

  ExampleExternalContract public exampleExternalContract;

  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  // (Make sure to add a `Stake(address,uint256)` event and emit it for the frontend `All Stakings` tab to display)
  function stake() public payable {
    balances[msg.sender] += msg.value;
    deadline = block.timestamp + 30 seconds;
    payable(address(this)).call{value:msg.value}("");
    emit Stake(msg.sender, msg.value);
  }

  modifier notExecuted() {
    require(!exampleExternalContract.completed(), "is executed already");
    _;
  }

  // After some `deadline` allow anyone to call an `execute()` function
  // If the deadline has passed and the threshold is met, it should call `exampleExternalContract.complete{value: address(this).balance}()`
  function execute() public notExecuted {
    console.log(block.timestamp >= deadline);
    console.log(address(this).balance >= threshold);
    if (block.timestamp >= deadline && address(this).balance >= threshold) {
        exampleExternalContract.complete{value: address(this).balance}();
    }
    openForWithdraw = true;
  }

  // If the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw their balance
  function withdraw() public noReentrant {
    if (!openForWithdraw) {revert("not open to withdraw");}
    uint256 balance = balances[msg.sender];
    require(balance > 0, "Insufficient funds");
    balances[msg.sender] = 0;
    (bool ok, ) = payable(msg.sender).call{value: balance}("");
    require(ok, "Failed to send Ether");
  }

  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256) {
    //1692471290 - 1692471261
    if(block.timestamp > deadline) {return 0;}
    return deadline - block.timestamp;
  }

  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
    stake();
  }

}
