// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

interface vcRegistryInterface {
    function getVcContractIndex(
        address _vcContract
    ) external returns (uint256);
}

contract VcEventTracker is Ownable {
    address public vcRegistry;
    mapping(address => bool) public vcContractDeployer;
    mapping(address => address) public vcContractCreatedByDeployer;
    mapping(address => uint256) public vcContractIndex;
    uint256 public buyEventCount;
    uint256 public sellEventCount;
    event buyCall(
        address indexed buyer,
        address indexed vcContract,
        uint256 buyAmount,
        uint256 tokenReceived,
        uint256 index,
        uint256 timestamp
    );
    event sellCall(
        address indexed seller,
        address indexed vcContract,
        uint256 sellAmount,
        uint256 nativeReceived,
        uint256 index,
        uint256 timestamp
    );
    event tradeCall(
        address indexed caller,
        address indexed vcContract,
        uint256 outAmount,
        uint256 inAmount,
        uint256 index,
        uint256 timestamp,
        string tradeType
    );
    event vcCreated(
        address indexed creator,
        address indexed vcContract,
        address indexed tokenAddress,
        string name,
        string symbol,
        string data,
        uint256 totalSupply,
        uint256 initialReserve,
        uint256 timestamp
    );

    event listed(
        address indexed user,
        address indexed tokenAddress,
        address indexed router,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 time,
        uint256 totalVolume
    );

    constructor(address _vcStorage) Ownable(msg.sender) {
        vcRegistry = _vcStorage;
    }

    function buyEvent(
        address _buyer,
        address _vcContract,
        uint256 _buyAmount,
        uint256 _tokenRecieved
    ) public {
        uint256 vcIndex;
        vcIndex = vcRegistryInterface(vcRegistry).getVcContractIndex(
            _vcContract
        );
        emit buyCall(
            _buyer,
            _vcContract,
            _buyAmount,
            _tokenRecieved,
            vcIndex,
            block.timestamp
        );
        emit tradeCall(
            _buyer,
            _vcContract,
            _buyAmount,
            _tokenRecieved,
            vcIndex,
            block.timestamp,
            "buy"
        );
        buyEventCount++;
    }

    function sellEvent(
        address _seller,
        address _vcContract,
        uint256 _sellAmount,
        uint256 _nativeRecieved
    ) public {
        uint256 vcIndex;
        vcIndex = vcRegistryInterface(vcRegistry).getVcContractIndex(
            _vcContract
        );
        emit sellCall(
            _seller,
            _vcContract,
            _sellAmount,
            _nativeRecieved,
            vcIndex,
            block.timestamp
        );
        emit tradeCall(
            _seller,
            _vcContract,
            _sellAmount,
            _nativeRecieved,
            vcIndex,
            block.timestamp,
            "sell"
        );
        sellEventCount++;
    }

    function createVcEvent(
        address creator,
        address vcContract,
        address tokenAddress,
        string memory name,
        string memory symbol,
        string memory data,
        uint256 totalSupply,
        uint256 initialReserve,
        uint256 timestamp
    ) public {
        vcContractCreatedByDeployer[vcContract] = msg.sender;
        vcContractIndex[vcContract] = vcRegistryInterface(vcRegistry)
            .getVcContractIndex(vcContract);
        emit vcCreated(
            creator,
            vcContract,
            tokenAddress,
            name,
            symbol,
            data,
            totalSupply,
            initialReserve,
            timestamp
        );
    }

    function listEvent(
        address user,
        address tokenAddress,
        address router,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    ) public {
        emit listed(
            user,
            tokenAddress,
            router,
            liquidityAmount,
            tokenAmount,
            _time,
            totalVolume
        );
    }

    function addDeployer(address _newDeployer) public onlyOwner {
        vcContractDeployer[_newDeployer] = true;
    }

    function removeDeployer(address _deployer) public onlyOwner {
        vcContractDeployer[_deployer] = false;
    }
}
