// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    Staking public staking;

    Staking.StakingInfo public stakingInfo;

    address User1 = address(0x1);
    address User2 = address(0x2);

    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        staking = new Staking(weth);
    }

    function testStaking() public payable {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: 1 ether}(true);

        // assertEq(staking.balanceOf(User1), 1 ether);
        assertTrue(stakingInfo.isAutoCompounding);
        assertTrue(stakingInfo.isStakingActive);
        assertEq(stakingInfo.stakingAmount, 1 ether);
        assertEq(stakingInfo.stakingReward, 0);
        assertEq(stakingInfo.stakingTime, block.timestamp);
        assertEq(stakingInfo.lastTimeStaked, 0);
    }
}
