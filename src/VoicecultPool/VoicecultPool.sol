// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {UniswapRouter02,UniswapFactory,LPToken,ILpLockDeployerInterface} from "./interfaces/IUniswap.sol";
import {IVcToken} from "./interfaces/IVcToken.sol";
import {IVcDeployer} from "./interfaces/IVcDeployer.sol";
import {IVcEventTracker} from "./interfaces/IVcEventTracker.sol";

contract VoicecultPool is Ownable, ReentrancyGuard {
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant HUNDRED = 100;
    uint256 public constant BASIS_POINTS = 10000;

    struct VcTokenPoolData {
        uint256 reserveTokens;
        uint256 reserveETH;
        uint256 volume;
        uint256 listThreshold;
        uint256 initialReserveEth;
        uint8 nativePer;
        bool tradeActive;
        bool lpBurn;
        bool royalemitted;
    }
    struct VcTokenPool {
        address creator;
        address token;
        address baseToken;
        address router;
        address lockerAddress;
        address storedLPAddress;
        address deployer;
        VcTokenPoolData pool;
    }

    // deployer allowed to create vc tokens
    mapping(address => bool) public allowedDeployers;
    // user => array of vc tokens
    mapping(address => address[]) public userVcTokens;
    // vc token => vc token details
    mapping(address => VcTokenPool) public tokenPools;

    address public implementation;
    address public feeContract;
    address public stableAddress;
    address public lpLockDeployer;
    address public eventTracker;
    uint16 public feePer;

    event LiquidityAdded(
        address indexed provider,
        uint tokenAmount,
        uint ethAmount
    );
    event sold(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 _time,
        uint256 reserveEth,
        uint256 reserveTokens,
        uint256 totalVolume
    );
    event bought(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 _time,
        uint256 reserveEth,
        uint256 reserveTokens,
        uint256 totalVolume
    );
    event vcTradeCall(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 _time,
        uint256 reserveEth,
        uint256 reserveTokens,
        string tradeType,
        uint256 totalVolume
    );
    event listed(
        address indexed user,
        address indexed tokenAddress,
        address indexed router,
        uint256 liquidityAmount,
        uint256 tokenAmount,
        uint256 _time,
        uint256 totalVolume
    );

    constructor(
        address _implementation,
        address _feeContract,
        address _lpLockDeployer,
        address _stableAddress,
        address _eventTracker,
        uint16 _feePer
    ) Ownable(msg.sender) payable {
        implementation = _implementation;
        feeContract = _feeContract;
        lpLockDeployer = _lpLockDeployer;
        stableAddress = _stableAddress;
        eventTracker = _eventTracker;
        feePer = _feePer;
    }

    function createVc(
        string[2] memory _name_symbol,
        uint256 _totalSupply,
        address _creator,
        address _baseToken,
        address _router,
        uint256[2] memory listThreshold_initReserveEth,
        bool lpBurn
    ) public payable returns (address) {
        address vcToken = Clones.clone(implementation);
        IVcToken(vcToken).initialize(
            _totalSupply,
            _name_symbol[0],
            _name_symbol[1],
            address(this),
            msg.sender
        );

        // add tokens to the tokens user list
        userVcTokens[_creator].push(vcToken);

        // create the pool data
        VcTokenPool memory pool;

        pool.creator = _creator;
        pool.token = vcToken;
        pool.baseToken = _baseToken;
        pool.router = _router;
        pool.deployer = msg.sender;

        // if (_baseToken == UniswapRouter02(_router).WETH()) {
        //     pool.pool.nativePer = 100;
        // } else {
            pool.pool.nativePer = 50;
        // }
        pool.pool.tradeActive = true;
        pool.pool.lpBurn = lpBurn;
        pool.pool.reserveTokens += _totalSupply;
        pool.pool.reserveETH += (listThreshold_initReserveEth[1] + msg.value);
        pool.pool.listThreshold = listThreshold_initReserveEth[0];
        pool.pool.initialReserveEth = listThreshold_initReserveEth[1];

        // add the vc data for the vc token
        tokenPools[vcToken] = pool;
        // tokenPoolData[vcToken] = vcPoolData;

        emit LiquidityAdded(address(this), _totalSupply, msg.value);

        return address(vcToken); // return vc token address
    }

    // Calculate amount of output tokens or ETH to give out
    function getAmountOutTokens(
        address vcToken,
        uint amountIn
    ) public view returns (uint amountOut) {
        require(amountIn > 0, "Invalid input amount");
        VcTokenPool storage token = tokenPools[vcToken];
        require(
            token.pool.reserveTokens > 0 && token.pool.reserveETH > 0,
            "Invalid reserves"
        );
        uint numerator = amountIn * token.pool.reserveTokens;
        uint denominator = (token.pool.reserveETH) + amountIn;
        amountOut = numerator / denominator;
    }

    function getAmountOutETH(
        address vcToken,
        uint amountIn
    ) public view returns (uint amountOut) {
        require(amountIn > 0, "Invalid input amount");
        VcTokenPool storage token = tokenPools[vcToken];
        require(
            token.pool.reserveTokens > 0 && token.pool.reserveETH > 0,
            "Invalid reserves"
        );
        uint numerator = amountIn * token.pool.reserveETH;
        uint denominator = (token.pool.reserveTokens) + amountIn;
        amountOut = numerator / denominator;
    }

    function getBaseToken(address vcToken) public view returns (address) {
        VcTokenPool storage token = tokenPools[vcToken];
        return address(token.baseToken);
    }

    function getWrapAddr(address vcToken) public view returns (address) {
        return UniswapRouter02(tokenPools[vcToken].router).WETH();
    }

    function getAmountsMinToken(
        address vcToken,
        address _tokenAddress,
        uint256 _ethIN
    ) public view returns (uint256) {
        // generate the pair path of token -> weth
        uint256[] memory amountMinArr;
        address[] memory path = new address[](2);
        path[0] = getWrapAddr(vcToken);
        path[1] = address(_tokenAddress);
        amountMinArr = UniswapRouter02(tokenPools[vcToken].router)
            .getAmountsOut(_ethIN, path);
        return uint256(amountMinArr[1]);
    }

    function getCurrentCap(address vcToken) public view returns (uint256) {
        VcTokenPool storage token = tokenPools[vcToken];
        return
            (getAmountsMinToken(
                vcToken,
                stableAddress,
                token.pool.reserveETH
            ) * IERC20(vcToken).totalSupply()) / token.pool.reserveTokens;
    }

    function getVctokenPool(address vcToken) public view returns(VcTokenPool memory) {
      return tokenPools[vcToken];
    }

    function getVctokenPools(address[] memory vcTokens) public view returns(VcTokenPool[] memory) {
      uint length = vcTokens.length;
      VcTokenPool[] memory pools = new VcTokenPool[](length);
      for( uint i=0 ;i < length;  ) {
        pools[i] = tokenPools[vcTokens[i]];
        unchecked {
          i++;
        }
      }
      return pools;
    }

     function getUserVctokens(address user) public view returns(address[] memory) {
      return userVcTokens[user];
    }

    function sellTokens(
        address vcToken,
        uint256 tokenAmount,
        uint256 minEth,
        address _affiliate
    ) public nonReentrant returns (bool, bool) {
        VcTokenPool storage token = tokenPools[vcToken];
        require(token.pool.tradeActive, "Trading not active");

        uint256 tokenToSell = tokenAmount;
        uint256 ethAmount = getAmountOutETH(vcToken, tokenToSell);
        uint256 ethAmountFee = (ethAmount * feePer) / BASIS_POINTS;
        uint256 ethAmountOwnerFee = (ethAmountFee *
            (IVcDeployer(token.deployer).getOwnerPer())) /
            BASIS_POINTS;
        uint256 affiliateFee = (ethAmountFee *
            (
                IVcDeployer(token.deployer).getAffiliatePer(
                    _affiliate
                )
            )) / BASIS_POINTS;
        require(ethAmount > 0 && ethAmount >= minEth, "Slippage too high");

        token.pool.reserveTokens += tokenAmount;
        token.pool.reserveETH -= ethAmount;
        token.pool.volume += ethAmount;

        IERC20(vcToken).transferFrom(msg.sender, address(this), tokenToSell);
        (bool success, ) = feeContract.call{
            value: ethAmountFee - ethAmountOwnerFee - affiliateFee
        }(""); // paying plat fee
        require(success, "fee ETH transfer failed");

        (success, ) = _affiliate.call{value: affiliateFee}(""); // paying affiliate fee which is same amount as plat fee %
        require(success, "aff ETH transfer failed");

        (success, ) = owner().call{value: ethAmountOwnerFee}(""); // paying owner fee per tx
        require(success, "ownr ETH transfer failed");

        (success, ) = msg.sender.call{value: ethAmount - ethAmountFee}("");
        require(success, "seller ETH transfer failed");

        emit sold(
            msg.sender,
            tokenAmount,
            ethAmount,
            block.timestamp,
            token.pool.reserveETH,
            token.pool.reserveTokens,
            token.pool.volume
        );
        emit vcTradeCall(
            msg.sender,
            tokenAmount,
            ethAmount,
            block.timestamp,
            token.pool.reserveETH,
            token.pool.reserveTokens,
            "sell",
            token.pool.volume
        );
        IVcEventTracker(eventTracker).sellEvent(
            msg.sender,
            vcToken,
            tokenToSell,
            ethAmount
        );

        return (true, true);
    }

    function buyTokens(
        address vcToken,
        uint256 minTokens,
        address _affiliate
    ) public payable nonReentrant {
        require(msg.value > 0, "Invalid buy value");
        VcTokenPool storage token = tokenPools[vcToken];
        require(token.pool.tradeActive, "Trading not active");

        {
            uint256 ethAmount = msg.value;
            uint256 ethAmountFee = (ethAmount * feePer) / BASIS_POINTS;
            uint256 ethAmountOwnerFee = (ethAmountFee *
                (IVcDeployer(token.deployer).getOwnerPer())) /
                BASIS_POINTS;
            uint256 affiliateFee = (ethAmountFee *
                (
                    IVcDeployer(token.deployer).getAffiliatePer(
                        _affiliate
                    )
                )) / BASIS_POINTS;

            uint256 tokenAmount = getAmountOutTokens(
                vcToken,
                ethAmount - ethAmountFee
            );
            require(tokenAmount >= minTokens, "Slippage too high");

            token.pool.reserveETH += (ethAmount - ethAmountFee);
            token.pool.reserveTokens -= tokenAmount;
            token.pool.volume += ethAmount;

            (bool success, ) = feeContract.call{
                value: ethAmountFee - ethAmountOwnerFee - affiliateFee
            }(""); // paying plat fee
            require(success, "fee ETH transfer failed");

            (success, ) = _affiliate.call{value: affiliateFee}(""); // paying affiliate fee which is same amount as plat fee %
            require(success, "fee ETH transfer failed");

            (success, ) = owner().call{value: ethAmountOwnerFee}(""); // paying owner fee per tx
            require(success, "fee ETH transfer failed");

            IERC20(vcToken).transfer(msg.sender, tokenAmount);
            emit bought(
                msg.sender,
                msg.value,
                tokenAmount,
                block.timestamp,
                token.pool.reserveETH,
                token.pool.reserveTokens,
                token.pool.volume
            );
            emit vcTradeCall(
                msg.sender,
                msg.value,
                tokenAmount,
                block.timestamp,
                token.pool.reserveETH,
                token.pool.reserveTokens,
                "buy",
                token.pool.volume
            );
            IVcEventTracker(eventTracker).buyEvent(
                msg.sender,
                vcToken,
                msg.value,
                tokenAmount
            );
        }

        uint currentMarketCap = getCurrentCap(vcToken);
        uint listThresholdCap = token.pool.listThreshold *
            10 ** IERC20(stableAddress).decimals();

        // using liquidity value inside contract to check when to add liquidity to DEX
        if (
            currentMarketCap >= (listThresholdCap / 2) &&
            !token.pool.royalemitted
        ) {
            IVcDeployer(token.deployer).emitRoyal(
                vcToken,
                vcToken,
                token.router,
                token.baseToken,
                token.pool.reserveETH,
                token.pool.reserveTokens,
                block.timestamp,
                token.pool.volume
            );
            token.pool.royalemitted = true;
        }
        // using marketcap value of token to check when to add liquidity to DEX
        if (currentMarketCap >= listThresholdCap) {
            token.pool.tradeActive = false;
            IVcToken(vcToken).initiateDex();
            token.pool.reserveETH -= token.pool.initialReserveEth;
            if (token.pool.nativePer > 0) {
                _addLiquidityETH(
                    vcToken,
                    (IERC20(vcToken).balanceOf(address(this)) *
                        token.pool.nativePer) / HUNDRED,
                    (token.pool.reserveETH * token.pool.nativePer) / HUNDRED,
                    token.pool.lpBurn
                );
                token.pool.reserveETH -=
                    (token.pool.reserveETH * token.pool.nativePer) /
                    HUNDRED;
            }
            if (token.pool.nativePer < HUNDRED) {
                _swapEthToBase(
                    vcToken,
                    token.baseToken,
                    token.pool.reserveETH
                );
                _addLiquidity(
                    vcToken,
                    IERC20(vcToken).balanceOf(address(this)),
                    IERC20(token.baseToken).balanceOf(address(this)),
                    token.pool.lpBurn
                );
            }
        }
    }

    function changeNativePer(address vcToken, uint8 _newNativePer) public {
        require(_isUserVcToken(vcToken), "Unauthorized");
        VcTokenPool storage token = tokenPools[vcToken];
        require(
            token.baseToken != getWrapAddr(vcToken),
            "no custom base selected"
        );
        require(_newNativePer >= 0 && _newNativePer <= 100, "invalid per");
        token.pool.nativePer = _newNativePer;
    }

    function _addLiquidityETH(
        address vcToken,
        uint256 amountTokenDesired,
        uint256 nativeForDex,
        bool lpBurn
    ) internal {
        uint256 amountETH = nativeForDex;
        uint256 amountETHMin = (amountETH * 90) / HUNDRED;
        uint256 amountTokenToAddLiq = amountTokenDesired;
        uint256 amountTokenMin = (amountTokenToAddLiq * 90) / HUNDRED;
        uint256 LP_WBNB_exp_balance;
        uint256 LP_token_balance;
        uint256 tokenToSend = 0;

        VcTokenPool storage token = tokenPools[vcToken];

        address wrapperAddress = getWrapAddr(vcToken);
        token.storedLPAddress = _getpair(vcToken, vcToken, wrapperAddress);
        address storedLPAddress = token.storedLPAddress;
        LP_WBNB_exp_balance = IERC20(wrapperAddress).balanceOf(storedLPAddress);
        LP_token_balance = IERC20(vcToken).balanceOf(storedLPAddress);

        if (
            storedLPAddress != address(0x0) &&
            (LP_WBNB_exp_balance > 0 && LP_token_balance <= 0)
        ) {
            tokenToSend =
                (amountTokenToAddLiq * LP_WBNB_exp_balance) /
                amountETH;

            IERC20(vcToken).transfer(storedLPAddress, tokenToSend);

            LPToken(storedLPAddress).sync();
            // sync after adding token
        }
        _approve(vcToken, false);

        if (lpBurn) {
            UniswapRouter02(token.router).addLiquidityETH{
                value: amountETH - LP_WBNB_exp_balance
            }(
                vcToken,
                amountTokenToAddLiq - tokenToSend,
                amountTokenMin,
                amountETHMin,
                DEAD,
                block.timestamp + (300)
            );
        } else {
            UniswapRouter02(token.router).addLiquidityETH{
                value: amountETH - LP_WBNB_exp_balance
            }(
                vcToken,
                amountTokenToAddLiq - tokenToSend,
                amountTokenMin,
                amountETHMin,
                address(this),
                block.timestamp + (300)
            );
            _approveLock(storedLPAddress, lpLockDeployer);
            token.lockerAddress = ILpLockDeployerInterface(lpLockDeployer)
                .createLPLocker(
                    storedLPAddress,
                    32503698000,
                    "logo",
                    IERC20(storedLPAddress).balanceOf(address(this)),
                    token.creator
                );
        }
        IVcEventTracker(eventTracker).listEvent(
            msg.sender,
            vcToken,
            token.router,
            amountETH - LP_WBNB_exp_balance,
            amountTokenToAddLiq - tokenToSend,
            block.timestamp,
            token.pool.volume
        );
        emit listed(
            msg.sender,
            vcToken,
            token.router,
            amountETH - LP_WBNB_exp_balance,
            amountTokenToAddLiq - tokenToSend,
            block.timestamp,
            token.pool.volume
        );
    }

    function _addLiquidity(
        address vcToken,
        uint256 amountTokenDesired,
        uint256 baseForDex,
        bool lpBurn
    ) internal {
        uint256 amountBase = baseForDex;
        uint256 amountBaseMin = (amountBase * 90) / HUNDRED;
        uint256 amountTokenToAddLiq = amountTokenDesired;
        uint256 amountTokenMin = (amountTokenToAddLiq * 90) / HUNDRED;
        uint256 LP_WBNB_exp_balance;
        uint256 LP_token_balance;
        uint256 tokenToSend = 0;

        VcTokenPool storage token = tokenPools[vcToken];

        token.storedLPAddress = _getpair(vcToken, vcToken, token.baseToken);
        address storedLPAddress = token.storedLPAddress;

        LP_WBNB_exp_balance = IERC20(token.baseToken).balanceOf(
            storedLPAddress
        );
        LP_token_balance = IERC20(vcToken).balanceOf(storedLPAddress);

        if (
            storedLPAddress != address(0x0) &&
            (LP_WBNB_exp_balance > 0 && LP_token_balance <= 0)
        ) {
            tokenToSend =
                (amountTokenToAddLiq * LP_WBNB_exp_balance) /
                amountBase;

            IERC20(vcToken).transfer(storedLPAddress, tokenToSend);

            LPToken(storedLPAddress).sync();
            // sync after adding token
        }
        _approve(vcToken, false);
        _approve(vcToken, true);
        if (lpBurn) {
            UniswapRouter02(token.router).addLiquidity(
                vcToken,
                token.baseToken,
                amountTokenToAddLiq - tokenToSend,
                amountBase - LP_WBNB_exp_balance,
                amountTokenMin,
                amountBaseMin,
                DEAD,
                block.timestamp + (300)
            );
        } else {
            UniswapRouter02(token.router).addLiquidity(
                vcToken,
                token.baseToken,
                amountTokenToAddLiq - tokenToSend,
                amountBase - LP_WBNB_exp_balance,
                amountTokenMin,
                amountBaseMin,
                address(this),
                block.timestamp + (300)
            );
            _approveLock(storedLPAddress, lpLockDeployer);
            token.lockerAddress = ILpLockDeployerInterface(lpLockDeployer)
                .createLPLocker(
                    storedLPAddress,
                    32503698000,
                    "logo",
                    IERC20(storedLPAddress).balanceOf(address(this)),
                    owner()
                );
        }
        IVcEventTracker(eventTracker).listEvent(
            msg.sender,
            vcToken,
            token.router,
            amountBase - LP_WBNB_exp_balance,
            amountTokenToAddLiq - tokenToSend,
            block.timestamp,
            token.pool.volume
        );
        emit listed(
            msg.sender,
            vcToken,
            token.router,
            amountBase - LP_WBNB_exp_balance,
            amountTokenToAddLiq - tokenToSend,
            block.timestamp,
            token.pool.volume
        );
    }

    function _swapEthToBase(
        address vcToken,
        address _baseAddress,
        uint256 _ethIN
    ) internal returns (uint256) {
        _approve(vcToken, true);
        // generate the pair path of token -> weth
        uint256[] memory amountMinArr;
        address[] memory path = new address[](2);
        path[0] = getWrapAddr(vcToken);
        path[1] = _baseAddress;
        uint256 minBase = (getAmountsMinToken(vcToken, _baseAddress, _ethIN) *
            90) / HUNDRED;

        amountMinArr = UniswapRouter02(tokenPools[vcToken].router)
            .swapExactETHForTokens{value: _ethIN}(
            minBase,
            path,
            address(this),
            block.timestamp + 300
        );
        return amountMinArr[1];
    }

    function _approve(
        address vcToken,
        bool isBaseToken
    ) internal returns (bool) {
        VcTokenPool storage token = tokenPools[vcToken];
        IERC20 token_ = IERC20(vcToken);
        if (isBaseToken) {
            token_ = IERC20(token.baseToken);
        }

        if (token_.allowance(address(this), token.router) == 0) {
            token_.approve(token.router, type(uint256).max);
        }
        return true;
    }

    function _approveLock(
        address _lp,
        address _lockDeployer
    ) internal returns (bool) {
        IERC20 lp_ = IERC20(_lp);
        if (lp_.allowance(address(this), _lockDeployer) == 0) {
            lp_.approve(_lockDeployer, type(uint256).max);
        }
        return true;
    }

    function _getpair(
        address vcToken,
        address _token1,
        address _token2
    ) internal returns (address) {
        address router = tokenPools[vcToken].router;
        address factory = UniswapRouter02(router).factory();
        address pair = UniswapFactory(factory).getPair(_token1, _token2);
        if (pair != address(0)) {
            return pair;
        } else {
            return UniswapFactory(factory).createPair(_token1, _token2);
        }
    }

    function _isUserVcToken(address vcToken) internal view returns (bool) {
        for (uint i = 0; i < userVcTokens[msg.sender].length; ) {
            if (vcToken == userVcTokens[msg.sender][i]) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    function addDeployer(address _deployer) public onlyOwner {
        allowedDeployers[_deployer] = true;
    }

    function removeDeployer(address _deployer) public onlyOwner {
        allowedDeployers[_deployer] = false;
    }

    function updateImplementation(address _implementation) public onlyOwner {
        require(_implementation != address(0));
        implementation = _implementation;
    }

    function updateFeeContract(address _newFeeContract) public onlyOwner {
        feeContract = _newFeeContract;
    }

    function updateLpLockDeployer(address _newLpLockDeployer) public onlyOwner {
        lpLockDeployer = _newLpLockDeployer;
    }

    function updateEventTracker(address _newEventTracker) public onlyOwner {
        eventTracker = _newEventTracker;
    }

    function updateStableAddress(address _newStableAddress) public onlyOwner {
        stableAddress = _newStableAddress;
    }

    function updateteamFeeper(uint16 _newFeePer) public onlyOwner {
        feePer = _newFeePer;
    }
}
