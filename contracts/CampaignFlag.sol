// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Campaign {
    bool public campaignActive;
    bool public succeeded;

    function finalize() external {
        campaignActive = false;
        succeeded = true;
    }

    function isOpen() external view returns (bool) {
        return campaignActive && !succeeded;
    }
}