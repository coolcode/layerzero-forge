// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console2 } from "forge-std/Test.sol";
import { MessagingFee } from "src/oapp/OApp.sol";
import { OptionsBuilder } from "src/relay/libs/OptionsBuilder.sol";
import { LzTest } from "./mocks/LzTest.sol";
import { SimpleBridge } from "src/examples/SimpleBridge.sol";

contract SimpleBridgeTest is LzTest {
    using OptionsBuilder for bytes;

    bytes bridgeByteCode = type(SimpleBridge).creationCode;
    uint32 aEid = 1;
    uint32 bEid = 2;

    SimpleBridge bridgeA;
    SimpleBridge bridgeB;

    address public owner = address(0xf);
    address public userA = address(0x1);
    address public userB = address(0x2);

    function setUp() public override {
        console2.log("setup Simple Bridge");
        vm.label(owner, "Owner");
        vm.label(userA, "UserA");
        vm.label(userB, "UserB");
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        bridgeA = SimpleBridge(_deployOApp(bridgeByteCode, abi.encode(address(endpoints[aEid]), owner)));
        bridgeB = SimpleBridge(_deployOApp(bridgeByteCode, abi.encode(address(endpoints[bEid]), owner)));
        address[] memory ofts = new address[](2);
        ofts[0] = address(bridgeA);
        ofts[1] = address(bridgeB);
        this.wireOApps(ofts);
    }

    function test_constructor() external {
        assertEq(bridgeA.owner(), owner);
        assertEq(bridgeB.owner(), owner);
    }

    function test_send_message() external {
        string memory message = "hello world!";
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        MessagingFee memory fee = bridgeA.quote(bEid, message, options, false);
        console2.log("fee:", fee.nativeFee);
        vm.prank(userA);
        bridgeA.send{ value: fee.nativeFee }(bEid, message, options);
        this.verifyPackets(bEid, addressToBytes32(address(bridgeB)));
    }
}
