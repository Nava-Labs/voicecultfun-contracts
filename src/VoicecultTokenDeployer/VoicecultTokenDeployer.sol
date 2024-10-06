// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {IVcStorageInterface} from "./interfaces/IVcStorageInterface.sol";
import {IVcEventTracker} from "./interfaces/IVcEventTracker.sol";
import {IVcPool} from "./interfaces/IVcPool.sol";

contract VoicecultTokenDeployer is Ownable {
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
    
    event royal(
        address indexed vcContract,
        address indexed tokenAddress,
        address indexed router,
        address baseAddress,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    );

    address public creationFeeDistributionContract;
    address public vcStorage;
    address public eventTracker;
    address public vcPool;
    uint256 public teamFee = 10000000; // value in wei
    uint256 public teamFeePer = 100; // base of 10000 -> 100 equals 1%
    uint256 public ownerFeePer = 1000; // base of 10000 -> 1000 means 10%
    uint256 public listThreshold = 12000; // value in ether -> 12000 means 12000 tokens(any decimal place)
    uint256 public antiSnipePer = 5; // base of 100 -> 5 equals 5%
    uint256 public supplyValue = 1000000000 ether;
    uint256 public initialReserveEth = 1 ether;
    uint256 public baseCount;
    bool public supplyLock = true;
    bool public lpBurn = true;
    mapping(address => bool) public baseValid;
    mapping(address => bool) public baseAdded;
    mapping(uint256 => address) public baseStorage;
    constructor(
        address _vcPool,
        address _creationFeeContract,
        address _vcStorage,
        address _eventTracker
    ) Ownable(msg.sender) {
        vcPool = _vcPool;
        creationFeeDistributionContract = _creationFeeContract;
        vcStorage = _vcStorage;
        eventTracker = _eventTracker;
    }

    function createVc(
        string memory _name,
        string memory _symbol,
        string memory _data,
        uint256 _totalSupply,
        uint256 _liquidityETHAmount,
        address _baseToken,
        address _router,
        bool _antiSnipe,
        uint256 _amountAntiSnipe
    ) public payable {
        if (supplyLock) {
            require(_totalSupply == supplyValue, "invalid supply");
        }

        if (_antiSnipe) {
            require(_amountAntiSnipe > 0, "invalid antisnipe value");
        }

        address vcToken = IVcPool(vcPool).createVc{
            value: _liquidityETHAmount
        }(
            [_name, _symbol],
            _totalSupply,
            msg.sender,
            _baseToken,
            _router,
            [listThreshold, initialReserveEth],
            lpBurn
        );

        IVcStorageInterface(vcStorage).addVcContract(
            msg.sender,
            (vcToken),
            vcToken,
            address(_router),
            _name,
            _symbol,
            _data,
            _totalSupply,
            _liquidityETHAmount
        );

        if (_antiSnipe) {
            IVcPool(vcPool).buyTokens{value: _amountAntiSnipe}(
                vcToken,
                0,
                msg.sender
            );
            IERC20(vcToken).transfer(
                msg.sender,
                IERC20(vcToken).balanceOf(address(this))
            );
        }

        IVcEventTracker(eventTracker).createVcEvent(
            msg.sender,
            (vcToken),
            (vcToken),
            _name,
            _symbol,
            _data,
            _totalSupply,
            initialReserveEth + _liquidityETHAmount,
            block.timestamp
        );

        emit vcCreated(
            msg.sender,
            (vcToken),
            (vcToken),
            _name,
            _symbol,
            _data,
            _totalSupply,
            initialReserveEth + _liquidityETHAmount,
            block.timestamp
        );
    }

    function updateTeamFee(uint256 _newTeamFeeInWei) public onlyOwner {
        teamFee = _newTeamFeeInWei;
    }

    function updateownerFee(uint256 _newOwnerFeeBaseTenK) public onlyOwner {
        ownerFeePer = _newOwnerFeeBaseTenK;
    }
    
    function getOwnerPer() public view returns (uint256) {
        return ownerFeePer;
    }
    function updateSupplyValue(uint256 _newSupplyVal) public onlyOwner {
        supplyValue = _newSupplyVal;
    }
    function updateInitResEthVal(uint256 _newVal) public onlyOwner {
        initialReserveEth = _newVal;
    }
    function stateChangeSupplyLock(bool _lockState) public onlyOwner {
        supplyLock = _lockState;
    }

    function updateVcData(
        uint256 _ownerVcCount,
        string memory _newData
    ) public {
        IVcStorageInterface(vcStorage).updateData(
            msg.sender,
            _ownerVcCount,
            _newData
        );
    }

    function updateVcPool(address _newVcPool) public onlyOwner {
        vcPool = _newVcPool;
    }

    function updateCreationFeeContract(
        address _newCreationFeeContract
    ) public onlyOwner {
        creationFeeDistributionContract = _newCreationFeeContract;
    }

    function updateStorageContract(
        address _newStorageContract
    ) public onlyOwner {
        vcStorage = _newStorageContract;
    }

    function updateEventContract(address _newEventContract) public onlyOwner {
        eventTracker = _newEventContract;
    }

    function updateListThreshold(uint256 _newListThreshold) public onlyOwner {
        listThreshold = _newListThreshold;
    }

    function updateAntiSnipePer(uint256 _newAntiSnipePer) public onlyOwner {
        antiSnipePer = _newAntiSnipePer;
    }

    function stateChangeLPBurn(bool _state) public onlyOwner {
        lpBurn = _state;
    }

    function updateteamFeeper(uint256 _newFeePer) public onlyOwner {
        teamFeePer = _newFeePer;
    }

    function emitRoyal(
        address vcContract,
        address tokenAddress,
        address router,
        address baseAddress,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    ) public {
        require(msg.sender == vcPool, "invalid caller");
        emit royal(
            vcContract,
            tokenAddress,
            router,
            baseAddress,
            liquidityAmount,
            tokenAmount,
            _time,
            totalVolume
        );
    }

    // Emergency withdrawal by owner
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
