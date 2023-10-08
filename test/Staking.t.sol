// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";

contract StakingTest is Test {
    Staking public staking;

    address User1 = address(0x1);
    address User2 = address(0x2);

    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public payable {
        staking = new Staking{value: msg.value}(weth);
    }

    function testStaking() public payable {
        vm.startPrank(User1);
        vm.deal(User1, 3 ether);
        staking.stake{value: msg.value}(true);
    }
}
