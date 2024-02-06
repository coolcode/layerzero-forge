// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { Packet } from "src/protocol/interfaces/ISendLib.sol";
import { MessagingFee } from "src/protocol/interfaces/ILayerZeroEndpointV2.sol";
import { SendUln302 } from "src/relay/uln/uln302/SendUln302.sol";
import { IRelayer } from "./IRelayer.sol";

contract SimpleSendUln is SendUln302 {
    // offchain packets schedule
    IRelayer relayer;

    constructor(address payable _relayer, address _endpoint, uint256 _treasuryGasCap, uint256 _treasuryGasForFeeCap)
        SendUln302(_endpoint, _treasuryGasCap, _treasuryGasForFeeCap)
    {
        relayer = IRelayer(_relayer);
    }

    function send(Packet calldata _packet, bytes calldata _options, bool _payInLzToken)
        public
        override
        returns (MessagingFee memory fee, bytes memory encodedPacket)
    {
        (fee, encodedPacket) = super.send(_packet, _options, _payInLzToken);
        console.log("schedule: %d, src: %s", _packet.srcEid, _packet.sender);
        relayer.schedulePacket(encodedPacket, _options);
    }
}
