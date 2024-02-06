// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { MessagingFee } from "src/oapp/OApp.sol";
import { OptionsBuilder } from "src/relay/libs/OptionsBuilder.sol";
import { LzTest } from "./mocks/LzTest.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { AmpBridge, AmpCodec } from "src/examples/AmpBridge.sol";

contract AmpBridgeTest is LzTest {
    using OptionsBuilder for bytes;

    bytes bridgeByteCode = type(AmpBridge).creationCode;
    uint32 aEid = 1;
    uint32 bEid = 2;
    uint32 cEid = 3;

    AmpBridge bridgeA;
    AmpBridge bridgeB;
    AmpBridge bridgeC;

    address public owner = address(0xf);
    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);
    ERC20Mock tokenA;
    ERC20Mock tokenB;

    function setUp() public override {
        console2.log("setup Amp Bridge");
        vm.label(owner, "Owner");
        vm.label(userA, "UserA");
        vm.label(userB, "UserB");
        vm.label(userC, "UserC");
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);
        super.setUp();
        setUpEndpoints(3, LibraryType.UltraLightNode);

        bridgeA = AmpBridge(_deployOApp(bridgeByteCode, abi.encode(address(endpoints[aEid]), owner)));
        bridgeB = AmpBridge(_deployOApp(bridgeByteCode, abi.encode(address(endpoints[bEid]), owner)));
        bridgeC = AmpBridge(_deployOApp(bridgeByteCode, abi.encode(address(endpoints[cEid]), owner)));

        tokenA = new ERC20Mock("aToken", "aToken");
        tokenB = new ERC20Mock("bToken", "bToken");

        address[] memory ofts = new address[](3);
        ofts[0] = address(bridgeA);
        ofts[1] = address(bridgeB);
        ofts[2] = address(bridgeC);
        this.wireOApps(ofts);
    }

    function test_constructor() external {
        assertEq(bridgeA.owner(), owner);
        assertEq(bridgeB.owner(), owner);
        assertEq(bridgeC.owner(), owner);
    }

    function test_send_message() external {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory payload = AmpCodec.encode(userA, "hello world!");
        MessagingFee memory fee = bridgeA.quote(bEid, payload, options, false);
        console2.log("fee:", fee.nativeFee);
        vm.prank(userA);
        bridgeA.send{ value: fee.nativeFee }(bEid, payload, options);
        this.verifyPackets(bEid, addressToBytes32(address(bridgeB)));
    }

    function test_send_token() external {
        uint256 initialBalance = 10 * 1e18;
        tokenA.mint(userA, initialBalance);
        vm.prank(userA);
        tokenA.approve(address(bridgeA), type(uint256).max);
        tokenB.mint(address(bridgeB), initialBalance);

        uint256 amountSent = 1e18;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        bytes memory payload = AmpCodec.encode(userA, amountSent, address(tokenA), address(tokenB));
        MessagingFee memory fee = bridgeA.quote(bEid, payload, options, false);
        console2.log("fee:", fee.nativeFee);
        vm.prank(userA);
        bridgeA.send{ value: fee.nativeFee }(bEid, payload, options);
        this.verifyPackets(bEid, addressToBytes32(address(bridgeB)));

        uint256 amountReceived = amountSent - amountSent * bridgeA.tokenFee() / 10000;
        assertEq(tokenA.balanceOf(userA), initialBalance - amountSent, "sender's token A");
        assertEq(tokenB.balanceOf(userA), amountReceived, "receiver's token B");
        assertEq(tokenA.balanceOf(address(bridgeA)), amountSent, "balance of bridge A");
        assertEq(tokenB.balanceOf(address(bridgeB)), initialBalance - amountReceived, "balance of bridge B");
    }
}
