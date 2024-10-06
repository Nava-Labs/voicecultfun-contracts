// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { TxFeeDistributor } from "../src/VoicecultUtils/TxFeeDistributor.sol";
import { VcStorage } from "../src/VoicecultUtils/VcStorage.sol";
import { VcEventTracker } from "../src/VoicecultUtils/VcEventTracker.sol";
import { VoicecultPool } from "../src/VoicecultPool/VoicecultPool.sol";
import { SimpleERC20 } from "../src/VoicecultPool/VcToken.sol";
import { VoicecultTokenDeployer } from "../src/VoicecultTokenDeployer/VoicecultTokenDeployer.sol";

contract VoicecultScript is Script {
    TxFeeDistributor internal _txFeeDistributor;
    VcStorage internal _vcStorage;
    VcEventTracker internal _vcEventTracker;
    SimpleERC20 internal _simpleERC20;
    VoicecultPool internal _vcPool;
    VoicecultTokenDeployer internal _vcTokenDeployer;


    address USDC = address(0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4);

    function _setUp() internal {}

    function run() public {
        _setUp();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        _txFeeDistributor = new TxFeeDistributor();
        _vcStorage = new VcStorage();
        _vcEventTracker = new VcEventTracker(address(_vcStorage));
        _simpleERC20 = new SimpleERC20();
    
        _vcPool = new VoicecultPool({
            _implementation: address(_simpleERC20),
            _feeContract: address(_txFeeDistributor),
            _lpLockDeployer: address(0x000),
            _stableAddress: USDC,
            _eventTracker: address(_vcEventTracker),
            _feePer: 100
        });

        _vcTokenDeployer = new VoicecultTokenDeployer({
            _vcPool: address(_vcPool),
            _creationFeeContract: address(0x000),
            _vcStorage: address(_vcStorage),
            _eventTracker: address(_vcEventTracker)            
        });

        vm.stopBroadcast();

        console.log(
            "TxFeeDistributor contract address: ",
            address(_txFeeDistributor)
        );
    }

}
