// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { console } from "forge-std/console.sol";
import { OApp, MessagingFee, Origin } from "src/oapp/OApp.sol";

contract SimpleBridge is OApp {
    event MessageSent(string message, uint32 dstEid);
    event MessageReceive(string message, uint32 srcEid, address _executor);

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) { }

    function quote(uint32 _dstEid, string memory _message, bytes memory _options, bool _payInLzToken)
        public
        view
        returns (MessagingFee memory fee)
    {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }

    function send(uint32 _dstEid, string calldata _message, bytes calldata _options) external payable {
        // Encodes the message before invoking _lzSend.
        bytes memory _payload = abi.encode(_message);
        _lzSend(
            _dstEid,
            _payload,
            _options,
            // Fee in native gas and ZRO token.
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );

        emit MessageSent(_message, _dstEid);
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32, /*_guid*/
        bytes calldata _payload,
        address _executor,
        bytes calldata /*_extraData*/
    ) internal override {
        console.log("receive msg:", string(_payload));
        emit MessageReceive(string(_payload), _origin.srcEid, _executor);
    }
}
