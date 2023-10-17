// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking, StakingInfo, Compound} from "../src/Staking.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingTest is Test {
    Staking public staking;
    IWETH public weth;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    StakingInfo public stakingInfo;

    Compound public _c;
    mapping(address => StakingInfo) idToStakeInfo;

    address User1 = address(0x1);
    address User2 = address(0x2);

    string MAINNET_RPC_URL =
        "https://eth-mainnet.g.alchemy.com/v2/pGzerS95yhhCdSbyUgbKAMKRpBvzh8I1";

    function setUp() public {
        vm.createFork(MAINNET_RPC_URL);
        weth = IWETH(WETH);
        vm.deal(address(this), 3 ether);
        staking = new Staking(address(weth));
    }

    function testStaking() public payable {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(Compound.Yes);

        assertEq(staking.balanceOf(User1), 1 ether);
    }

    function testStakingFailValue() public payable {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        vm.expectRevert(Staking.AmountShouldBeGreaterThanZero.selector);
        staking.stake{value: 0.01 ether}(Compound.Yes);
    }

    function testStakingFailIfOwner() public payable {
        vm.deal(address(this), 3 ether);
        vm.expectRevert(Staking.OwnerCannotStake.selector);
        staking.stake{value: 1 ether}(Compound.Yes);
    }

    function testEnableAutoCompounding() public {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(Compound.No);
        staking.enableAutoCompounding();
    }

    function testEnableAutoCompoundingFail() public {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(Compound.Yes);
        vm.expectRevert(Staking.AutoCompoundingIsAlreadyEnabled.selector);
        staking.enableAutoCompounding();
    }

    function testExecuteAutoCompounding() public {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(Compound.Yes);
        vm.stopPrank();

        vm.startPrank(User2);
        vm.warp(block.timestamp + 32 days);
        staking.executeAutoCompounding();
        vm.stopPrank();
    }

    function testFailWithdrawRewards() public {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(Compound.Yes);
        staking.withdrawRewards(200);
    }

    // function testWithdrawRewards() public payable {
    //     vm.startPrank(User1);
    //     vm.deal(User1, 3 ether);
    //     staking.stake{value: 1 ether}(true);
    //     stakingInfo.stakingTime = 30 days;
    //     // vm.warp(block.timestamp + 40 days);
    //     staking.withdrawRewards(10);
    // }
}
