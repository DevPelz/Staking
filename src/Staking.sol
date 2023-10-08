// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol";
import {RewardToken} from "./Reward.sol";

contract Staking is ERC20 {
    address public Weth;
    address public owner;
    address public wethtodpt;
    RewardToken public rewardToken;

    uint256 public totalPayForExecutor;

    error AmountShouldBeGreaterThanZero();
    error InvalidAddress();
    error OwnerCannotStake();
    error StakingIsNotActive();
    error AutoCompoundingIsAlreadyEnabled();
    error InsufficientFunds();
    error MinimumStakingTimeIsNotPassed();

    // events
    event Staked(
        address indexed staker,
        uint256 indexed stakingTime,
        uint256 stakingAmount
    );
    event WithdrawRewards(
        address indexed staker,
        uint256 indexed withdraw,
        uint256 withdrawal
    );

    event WithdrawStakedTokensAndRewards(
        address indexed staker,
        uint256 indexed withdrawEth,
        uint256 withdrawalReward
    );

    event AutoCompounded(uint256 timeCompounded);

    constructor(address _Weth) payable ERC20("DEV PELZ TOKEN", "DPT") {
        Weth = _Weth;
        owner = msg.sender;
        IUniswapV2Router01 uniswapV2Router01 = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        IERC20(rewardToken).approve(
            address(uniswapV2Router01),
            1000000000000 * 10 ** 18
        );
        uniswapV2Router01.addLiquidityETH{value: msg.value}(
            address(rewardToken),
            balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );
    }

    // add liquidity eth and dpt
    function addLiquidityEth(uint256 dpt) public payable {
        require(msg.sender == owner, "only owner can add liquidity");
        IUniswapV2Router01 uniswapV2Router01 = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        IERC20(rewardToken).approve(
            address(uniswapV2Router01),
            100000000000000000 * 10 ** 18
        );
        uniswapV2Router01.addLiquidityETH{value: msg.value}(
            address(rewardToken),
            dpt,
            0,
            0,
            address(this),
            block.timestamp + 1 days
        );
    }

    struct StakingInfo {
        uint256 stakingAmount;
        uint256 stakingTime;
        uint256 lastTimeStaked;
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

        uint lastStake = block.timestamp -
            idToStakingInfo[msg.sender].lastTimeStaked;
        uint rewards = idToStakingInfo[msg.sender].stakingReward;
        _mint(msg.sender, msg.value);

        StakingInfo memory stakingInfo = StakingInfo(
            msg.value,
            block.timestamp,
            lastStake,
            rewards,
            true,
            _compound
        );
        idToStakingInfo[msg.sender] = stakingInfo;

        if (idToStakingInfo[msg.sender].isAutoCompounding) {
            stakersWithAutoCompounding.push(msg.sender);
        } else {
            stakersWithoutAutoCompounding.push(msg.sender);
        }

        emit Staked(msg.sender, block.timestamp, msg.value);
    }

    // swap dpt to weth
    function swapDptToWeth(uint256 _dptAmtIn) internal {
        // swap dpt to weth

        IUniswapV2Router01 uniswapV2Router01 = IUniswapV2Router01(
            0xf164fC0Ec4E93095b804a4795bBe1e041497b92a
        );
        IERC20(rewardToken).approve(
            address(uniswapV2Router01),
            100000000000000000 * 10 ** 18
        );
        address[] memory path = new address[](2);

        path[0] = address(rewardToken);
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
        return stakingReward * 10;
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
    function calcSplit(address id) internal view returns (uint256) {
        uint onepercent = (idToStakingInfo[id].stakingAmount * 1) / 100;
        uint256 split = onepercent / 2;
        return split;
    }

    // execute auto compounding for all stakers that their stake duration is up to a month
    function executeAutoCompounding() external {
        for (uint256 i = 0; i < stakersWithAutoCompounding.length; i++) {
            address staker = stakersWithAutoCompounding[i];
            if (
                block.timestamp - idToStakingInfo[staker].stakingTime <
                30 days ||
                idToStakingInfo[staker].stakingReward == 0
            ) {
                continue;
            }
            uint256 stakingReward = calculateStakingReward(staker);
            uint rewards = idToStakingInfo[staker].stakingReward = 0;

            // update staking amount
            uint diff = stakingReward + idToStakingInfo[staker].stakingAmount;

            // mint new tokens
            _mint(staker, diff);

            uint lastStake = idToStakingInfo[staker].stakingTime;

            uint256 _stake = idToStakingInfo[staker].stakingAmount;

            StakingInfo memory stakingInfo = StakingInfo(
                _stake += diff,
                block.timestamp,
                lastStake,
                rewards,
                true,
                true
            );
            idToStakingInfo[staker] = stakingInfo;

            uint pay = calcSplit(staker);
            totalPayForExecutor += pay;
        }

        IERC20(Weth).transfer(msg.sender, totalPayForExecutor);
        emit AutoCompounded(block.timestamp);
    }

    // withdraw rewards
    function withdrawRewards(uint256 _amount) external {
        if (
            block.timestamp < idToStakingInfo[msg.sender].stakingTime + 7 days
        ) {
            revert MinimumStakingTimeIsNotPassed();
        }
        if (idToStakingInfo[msg.sender].isStakingActive == false) {
            revert StakingIsNotActive();
        }

        if (_amount <= 0) {
            revert AmountShouldBeGreaterThanZero();
        }
        uint256 stakingReward = calculateStakingReward(msg.sender);

        if (stakingReward == 0 || stakingReward < _amount) {
            revert InsufficientFunds();
        }

        rewardToken.mint(msg.sender, _amount);
        emit WithdrawRewards(msg.sender, block.timestamp, _amount);
    }

    // withdraw staked tokens and rewards
    function withdrawStakedTokensAndRewards() external {
        if (
            block.timestamp < idToStakingInfo[msg.sender].stakingTime + 7 days
        ) {
            revert MinimumStakingTimeIsNotPassed();
        }
        if (idToStakingInfo[msg.sender].isStakingActive == false) {
            revert StakingIsNotActive();
        }

        uint256 stakingReward = calculateStakingReward(msg.sender);

        uint256 total = idToStakingInfo[msg.sender].stakingAmount;

        delete idToStakingInfo[msg.sender];
        _burn(msg.sender, total);

        IWETH(Weth).withdraw(total);

        rewardToken.mint(msg.sender, stakingReward);
        (bool s, ) = payable(msg.sender).call{value: total}("");
        require(s);

        emit WithdrawStakedTokensAndRewards(msg.sender, total, stakingReward);
    }
}
