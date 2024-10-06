// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract TxFeeDistributor is Ownable {
    address[] public shareholders;
    mapping(address => uint256) public shares;  // Shares for each shareholder
    mapping(address => bool) public isShareholder;
    mapping(address => bool) public whitelisted;
    uint256 public totalShares;
    uint256 public totalAmount;
    event FeeDistributed(address indexed recipient, uint256 amount);
    event SharesUpdated(address indexed shareholder, uint256 oldShares, uint256 newShares);
    event ShareholderAdded(address indexed shareholder);
    event ShareholderRemoved(address indexed shareholder);

    constructor() Ownable(msg.sender) {}


    // Function to set shares for a shareholder
    function setShares(address _shareHolder, uint256 _share) public onlyOwner {
        require(_shareHolder != address(0), "Invalid address");
        require(_share >= 0 && _share <= 10000, "Invalid share percentage");

        if (isShareholder[_shareHolder]) {
            totalShares = totalShares - shares[_shareHolder] + _share;
            shares[_shareHolder] = _share;
            if (_share == 0) {
                removeShareholder(_shareHolder);
            }
        } else {
            require(_share > 0, "Share must be greater than 0 to add shareholder");
            addShareholder(_shareHolder);
            shares[_shareHolder] = _share;
            totalShares += _share;
        }

        emit SharesUpdated(_shareHolder, shares[_shareHolder], _share);
    }

// Function to edit shares for an existing shareholder
    function editShares(address shareholder, uint256 newShare) public onlyOwner {
        require(shareholder != address(0), "Invalid address");
        require(newShare >= 0 && newShare <= 10000, "Invalid share percentage");
        require(isShareholder[shareholder], "Address is not a shareholder");

        uint256 currentShare = shares[shareholder];
        if (newShare == 0) {
            // If the new share is zero, remove the shareholder
            removeShareholder(shareholder);
        } else if (currentShare == 0 && newShare > 0) {
            // If currently no shares and new shares are added, add as shareholder
            addShareholder(shareholder);
        }

        // Update total shares and shareholder's shares
        totalShares = totalShares - currentShare + newShare;
        shares[shareholder] = newShare;

        emit SharesUpdated(shareholder, currentShare, newShare);
    }



    // Function to distribute fees among shareholders based on their shares
    function distributeFees() public {
        require(whitelisted[msg.sender],"not whitelisted");
        uint256 totalReceived = address(this).balance;

        for (uint i = 0; i < shareholders.length; i++) {
            uint256 payment = totalReceived * shares[shareholders[i]] / totalShares;
            (bool distributionSuccess,) = payable(shareholders[i]).call{value:payment}("");
            emit FeeDistributed(shareholders[i], payment);
        }
    }

    // Helper functions to manage shareholders
    function addShareholder(address shareholder) internal {
        isShareholder[shareholder] = true;
        shareholders.push(shareholder);
        emit ShareholderAdded(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        isShareholder[shareholder] = false;
        for (uint i = 0; i < shareholders.length; i++) {
            if (shareholders[i] == shareholder) {
                shareholders[i] = shareholders[shareholders.length - 1];
                shareholders.pop();
                break;
            }
        }
        emit ShareholderRemoved(shareholder);
    }

    function disableHolder(address _holder) public onlyOwner{

        require(isShareholder[_holder], "not a holder");
        isShareholder[_holder] = false;

    }
    function enableHolder(address _holder) public onlyOwner{

        require(!isShareholder[_holder], "already a holder");
        isShareholder[_holder] = true;

    }
    // Emergency withdrawal by owner
    function emergencyWithdraw() public onlyOwner returns(bool) {
        uint256 balance = address(this).balance;
        (bool withdrawSuccess,) = payable(owner()).call{value: balance}("");
        return withdrawSuccess;
    }
    // Emergency withdrawal by owner
    function emergencyWithdrawTokens(address _token, uint256 _amount) public onlyOwner {

        IERC20(_token).transfer(owner(),_amount);

    }
    // View the balance of the contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function addWhitelist(address _addWhitelistAddress) public onlyOwner {
        require(!whitelisted[_addWhitelistAddress],"already whitelist addrs");
        whitelisted[_addWhitelistAddress] = true;
    }

    function removeWhitelist(address _removeWhitelistAddress) public onlyOwner {
        require(whitelisted[_removeWhitelistAddress],"not whitelist addrs");
        whitelisted[_removeWhitelistAddress] = false;
    }

    receive() external payable {
        totalAmount = totalAmount + msg.value;
    }

}
