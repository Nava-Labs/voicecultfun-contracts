// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVcStorageInterface {
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
    ) external;
    function getVcContractOwner(
        address _vcContract
    ) external view returns (address);
    function updateData(
        address _vcOwner,
        uint256 _ownerVcNumber,
        string memory _data
    ) external;
    function addDeployer(address) external;
    function owner() external view;
}
