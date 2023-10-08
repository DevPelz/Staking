// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol";

contract Staking is ERC20 {
    address public Weth;
    address public owner;
    address public wethtodpt;

    uint256 public stakingIds;
    uint256 public compondingPool;

    error AmountShouldBeGreaterThanZero();
    error InvalidAddress();
    error OwnerCannotStake();
    error StakingIsNotActive();
    error AutoCompoundingIsAlreadyEnabled();

    // events
    event Staked(
        address indexed staker,
        uint256 indexed stakingId,
        uint256 indexed stakingTime,
        uint256 stakingAmount
    );

    constructor(address _Weth) ERC20("DEV PELZ TOKEN", "DPT") {
        Weth = _Weth;
        owner = msg.sender;
        _mint(msg.sender, 10000000000000000 * 10 ** 18);
    }

    // add liquidity for weth and dpt
    function addLiquidity(uint256 weth, uint256 dpt) external {
        require(msg.sender == owner, "only owner can add liquidity");
        IUniswapV2Router01 uniswapV2Router01 = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        IERC20(Weth).approve(address(uniswapV2Router01), weth * 10 ** 18);
        IERC20(address(this)).approve(
            address(uniswapV2Router01),
            dpt * 10 ** 18
        );
        uniswapV2Router01.addLiquidity(
            Weth,
            address(this),
            weth,
            dpt,
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );
    }

    struct StakingInfo {
        uint256 stakingId;
        uint256 stakingTime;
        uint256 stakingAmount;
        uint256 stakingReward;
        bool isStakingActive;
        bool isAutoCompounding;
    }

    address[] public stakersWithAutoCompounding;
    address[] public stakersWithoutAutoCompounding;

    mapping(address => StakingInfo) idToStakingInfo;

    // stake tokens
    function stake(bool _compound) external payable {
        if (msg.sender == owner) {
            revert OwnerCannotStake();
        }

        if (msg.value <= 0.01 ether) {
            revert AmountShouldBeGreaterThanZero();
        }

        IWETH(Weth).deposit{value: msg.value}();
        _mint(msg.sender, msg.value);

        stakingIds++;
        StakingInfo memory stakingInfo = StakingInfo(
            stakingIds,
            msg.value,
            block.timestamp,
            0,
            true,
            _compound
        );
        idToStakingInfo[msg.sender] = stakingInfo;

        uint onepercent = (msg.value * 1) / 100;

        if (idToStakingInfo[msg.sender].isAutoCompounding) {
            compondingPool += onepercent;
            stakersWithAutoCompounding.push(msg.sender);
        } else {
            stakersWithoutAutoCompounding.push(msg.sender);
        }

        emit Staked(msg.sender, stakingIds, block.timestamp, msg.value);
    }

    // swap dpt to weth
    function swapDptToWeth(uint256 _dptAmtIn) internal {
        // swap dpt to weth

        IUniswapV2Router01 uniswapV2Router01 = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        address[] memory path = new address[](2);

        path[0] = address(this);
        path[1] = Weth;

        uniswapV2Router01.swapExactTokensForTokens(
            _dptAmtIn,
            0,
            path,
            address(this),
            block.timestamp + 1 days
        );
    }

    // calculate staking reward at 14% per annum
    function calculateStakingReward(
        address _stakingId
    ) internal view returns (uint256) {
        StakingInfo memory stakingInfo = idToStakingInfo[_stakingId];
        uint256 stakingTime = block.timestamp - stakingInfo.stakingTime;
        uint256 stakingReward = (stakingTime *
            14 *
            idToStakingInfo[_stakingId].stakingAmount) /
            365 days /
            100;
        return stakingReward;
    }

    //  enable auto compounding
    function enableAutoCompounding() external {
        if (idToStakingInfo[msg.sender].isAutoCompounding) {
            revert AutoCompoundingIsAlreadyEnabled();
        }
        idToStakingInfo[msg.sender].isAutoCompounding = true;
        stakersWithAutoCompounding.push(msg.sender);
    }

    // split pool fee 50 / 50
    function calcSplit() internal view returns (uint256) {
        uint256 split = compondingPool / 2;
        return split;
    }

    // execute auto compounding for all stakers that their stake duration is up to a month
    function executeAutoCompounding() external {
        for (uint256 i = 0; i < stakersWithAutoCompounding.length; i++) {
            address staker = stakersWithAutoCompounding[i];
            if (
                block.timestamp - idToStakingInfo[staker].stakingTime < 30 days
            ) {
                continue;
            }
            uint256 stakingReward = calculateStakingReward(staker);
            idToStakingInfo[staker].stakingTime = block.timestamp;
            swapDptToWeth(stakingReward);
        }
    }
}
