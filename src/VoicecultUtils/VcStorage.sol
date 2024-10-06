// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract VcStorage is Ownable {
    struct VcDetails {
        address vcAddress;
        address tokenAddress;
        address vcOwner;
        address router;
        string name;
        string symbol;
        string data;
        uint256 totalSupply;
        uint256 initialLiquidity;
        uint256 createdOn;
    }

    VcDetails[] public vcContracts;
    mapping(address => bool) public deployer;
    mapping(address => uint256) public vcContractToIndex;
    mapping(address => uint256) public tokenContractToIndex;
    mapping(address => uint256) public ownerToVcCount;
    mapping(address => mapping(uint256 => uint256))
        public ownerIndexToStorageIndex;
    mapping(address => address) public vcContractToOwner;
    mapping(address => uint256) public vcContractToOwnerCount;
    uint256 public vcCount;

    constructor() Ownable(msg.sender) {}

    function addVcContract(
        address _vcOwner,
        address _vcAddress,
        address _tokenAddress,
        address _routerAddress,
        string memory _name,
        string memory _symbol,
        string memory _data,
        uint256 _totalSupply,
        uint256 _initialLiquidity
    ) external {
        VcDetails memory newVc = VcDetails({
            vcAddress: _vcAddress,
            tokenAddress: _tokenAddress,
            vcOwner: _vcOwner,
            router: _routerAddress,
            name: _name,
            symbol: _symbol,
            data: _data,
            totalSupply: _totalSupply,
            initialLiquidity: _initialLiquidity,
            createdOn: block.timestamp
        });
        vcContracts.push(newVc);
        vcContractToIndex[_vcAddress] = vcContracts.length - 1;
        tokenContractToIndex[_tokenAddress] = vcContracts.length - 1;
        vcContractToOwner[_vcAddress] = _vcOwner;
        vcContractToOwnerCount[_vcAddress] = ownerToVcCount[_vcOwner]; // new addition for deployment after base
        ownerIndexToStorageIndex[_vcOwner][
            ownerToVcCount[_vcOwner]
        ] = vcCount;
        ownerToVcCount[_vcOwner]++;
        vcCount++;
        // return true;
    }

    function updateData(
        address _vcOwner,
        uint256 _ownerVcIndex,
        string memory _data
    ) external {
        require(
            _ownerVcIndex < ownerToVcCount[_vcOwner],
            "invalid owner vc count"
        );
        require(
            vcContracts[ownerIndexToStorageIndex[_vcOwner][_ownerVcIndex]]
                .vcOwner == _vcOwner,
            "invalid caller"
        );
        vcContracts[ownerIndexToStorageIndex[_vcOwner][_ownerVcIndex]]
            .data = _data;
    }
    function getVcContract(
        uint256 index
    ) public view returns (VcDetails memory) {
        return vcContracts[index];
    }
    function getVcContractIndex(
        address _vcContract
    ) public view returns (uint256) {
        return vcContractToIndex[_vcContract];
    }
    function getTotalContracts() public view returns (uint) {
        return vcContracts.length;
    }

    function getVcContractOwner(
        address _vcContract
    ) public view returns (address) {
        return vcContractToOwner[_vcContract];
    }

    function addDeployer(address _deployer) public onlyOwner {
        require(!deployer[_deployer], "already added");
        deployer[_deployer] = true;
    }
    function removeDeployer(address _deployer) public onlyOwner {
        require(deployer[_deployer], "not deployer");
        deployer[_deployer] = false;
    }
    // Emergency withdrawal by owner
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
