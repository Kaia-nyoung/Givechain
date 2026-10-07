// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum Category {
    EDU,
    HEALTH,
    ENV,
    ART
}

contract GivechainMini {
    uint256 public goal = 10 ether;
    uint256 public totalDonated;

    bool public campaignActive = true;

    address payable public beneficiary;

    mapping(address => uint256) public donations;

    constructor(address payable initialBeneficiary) {
        beneficiary = initialBeneficiary;
    }

    function donate() external payable {
        require(campaignActive);

        totalDonated += msg.value;
        donations[msg.sender] += msg.value;
    }

    function withdraw() external {
        require(msg.sender == beneficiary);

        uint256 balance = address(this).balance;

        (bool success, ) =
            beneficiary.call{value: balance}("");

        require(success, "Withdrawal failed");
    }
}