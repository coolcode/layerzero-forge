// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { console } from "forge-std/console.sol";
import { AmpCodec } from "./libs/AmpCodec.sol";
import { OApp, MessagingFee, Origin } from "src/oapp/OApp.sol";

contract AmpBridge is OApp {
    using AmpCodec for bytes;

    event MessageSent(bytes message, uint32 dstEid);
    event MessageReceive(bytes message, uint32 srcEid, address _executor);

    uint256 private _tokenFee = 3; // 0.03%

    constructor(address _endpoint, address _owner) OApp(_endpoint, _owner) { }

    function quote(uint32 _dstEid, bytes memory _payload, bytes memory _options, bool _payInLzToken)
        public
        view
        returns (MessagingFee memory fee)
    {
        fee = _quote(_dstEid, _payload, _options, _payInLzToken);
    }

    function send(uint32 _dstEid, bytes calldata _payload, bytes calldata _options) external payable {
        uint8 msgType = _payload.msgType();
        if (msgType == AmpCodec.ERC20) {
            (address srcToken,) = _payload.tokenPair();
            //TODO: check token pair
            IERC20(srcToken).transferFrom(msg.sender, address(this), _payload.value());
        }
        _lzSend(
            _dstEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            // Refund address in case of failed source message.
            payable(msg.sender)
        );

        logMsg("send to", _payload);
        emit MessageSent(_payload, _dstEid);
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32, /*_guid*/
        bytes calldata _payload,
        address _executor,
        bytes calldata /*_extraData*/
    ) internal override {
        logMsg("receive", _payload);
        uint8 msgType = _payload.msgType();
        if (msgType == AmpCodec.ERC20) {
            (, address dstToken) = _payload.tokenPair();
            //TODO: check token pair
            IERC20(dstToken).transfer(_payload.receiver(), _payload.value() - _payload.value() * _tokenFee / 10000);
        }
        emit MessageReceive(_payload, _origin.srcEid, _executor);
    }

    function tokenFee() external view returns (uint256) {
        return _tokenFee;
    }

    function logMsg(string memory _title, bytes calldata _payload) private view {
        uint8 msgType = _payload.msgType();
        if (msgType == AmpCodec.RAW) {
            console.log("%s: %s, %s", _title, _payload.receiver(), string(_payload.body()));
        } else if (msgType == AmpCodec.ERC20) {
            (address srcToken, address dstToken) = _payload.tokenPair();
            console.log("%s: %s, amount: %s", _title, _payload.receiver(), _payload.value());
            console.log("token: %s, %s", IERC20Metadata(srcToken).name(), IERC20Metadata(dstToken).name());
        }
    }
}
