// SPDX-License-Identifier: LZBL-1.2

pragma solidity 0.8.22;

import { console } from "forge-std/console.sol";
import { PacketV1Codec } from "src/protocol/messagelib/libs/PacketV1Codec.sol";
import { SetConfigParam } from "src/protocol/interfaces/IMessageLibManager.sol";
import { ILayerZeroEndpointV2, Origin } from "src/protocol/interfaces/ILayerZeroEndpointV2.sol";
import { IReceiveUlnE2 } from "src/relay/uln/interfaces/IReceiveUlnE2.sol";
import { VerificationState, ReceiveUlnBase } from "src/relay/uln/ReceiveUlnBase.sol";
import { ReceiveLibBaseE2 } from "src/relay/ReceiveLibBaseE2.sol";
import { UlnConfig } from "src/relay/uln/UlnBase.sol";
import { StringLib } from "../libs/StringLib.sol";

contract SimpleReceiveUln is IReceiveUlnE2, ReceiveUlnBase, ReceiveLibBaseE2 {
    using PacketV1Codec for bytes;
    using StringLib for bytes;
    using StringLib for bytes32;

    /// @dev CONFIG_TYPE_ULN=2 here to align with SendUln302/ReceiveUln302/ReceiveUln301
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    error InvalidConfigType(uint32 configType);

    constructor(address _endpoint) ReceiveLibBaseE2(_endpoint) { }

    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return _interfaceId == type(IReceiveUlnE2).interfaceId || super.supportsInterface(_interfaceId);
    }

    // ============================ OnlyEndpoint ===================================

    // only the ULN config on the receive side
    function setConfig(address _oapp, SetConfigParam[] calldata _params) external override onlyEndpoint {
        for (uint256 i = 0; i < _params.length; i++) {
            SetConfigParam calldata param = _params[i];
            _assertSupportedEid(param.eid);
            if (param.configType == CONFIG_TYPE_ULN) {
                _setUlnConfig(param.eid, _oapp, abi.decode(param.config, (UlnConfig)));
            } else {
                revert InvalidConfigType(param.configType);
            }
        }
    }

    // ============================ External ===================================

    /// @dev dont need to check endpoint verifiable here to save gas, as it will reverts if not verifiable.
    function commitVerification(bytes calldata _packetHeader, bytes32 _payloadHash) external {
        console.log("commit, header: %s,  payload hash:%s", _packetHeader.toHex(), _payloadHash.toHex());
        _assertHeader(_packetHeader, localEid);

        // cache these values to save gas
        address receiver = _packetHeader.receiverB20();
        uint32 srcEid = _packetHeader.srcEid();

        UlnConfig memory config = getUlnConfig(receiver, srcEid);
        _verifyAndReclaimStorage(config, keccak256(_packetHeader), _payloadHash);

        Origin memory origin = Origin(srcEid, _packetHeader.sender(), _packetHeader.nonce());
        // endpoint will revert if nonce <= lazyInboundNonce
        ILayerZeroEndpointV2(endpoint).verify(origin, receiver, _payloadHash);
    }

    /// @dev for dvn to verify the payload
    function verify(bytes calldata _packetHeader, bytes32 _payloadHash, uint64 _confirmations) external {
        console.log(
            "verify, header: %s,  payload hash: %s, confirmations: %d",
            _packetHeader.toHex(),
            _payloadHash.toHex(),
            _confirmations
        );
        _verify(_packetHeader, _payloadHash, _confirmations);
    }

    // ============================ View ===================================

    function getConfig(uint32 _eid, address _oapp, uint32 _configType) external view override returns (bytes memory) {
        if (_configType == CONFIG_TYPE_ULN) {
            return abi.encode(getUlnConfig(_oapp, _eid));
        } else {
            revert InvalidConfigType(_configType);
        }
    }

    function isSupportedEid(uint32 _eid) external view override returns (bool) {
        return _isSupportedEid(_eid);
    }

    function version() external pure override returns (uint64 major, uint8 minor, uint8 endpointVersion) {
        return (3, 0, 24);
    }

    // ========================= VIEW FUNCTIONS FOR OFFCHAIN ONLY =========================
    // Not involved in any state transition function.
    // ====================================================================================

    /// @dev a ULN verifiable requires it to be endpoint verifiable and committable
    function verifiable(bytes calldata _packetHeader, bytes32 _payloadHash) external view returns (VerificationState) {
        _assertHeader(_packetHeader, localEid);

        address receiver = _packetHeader.receiverB20();
        uint32 srcEid = _packetHeader.srcEid();

        // check endpoint verifiable
        if (!_verifiable(srcEid, receiver, _packetHeader, _payloadHash)) {
            return VerificationState.Verified;
        }

        // check uln verifiable
        if (_checkVerifiable(getUlnConfig(receiver, srcEid), keccak256(_packetHeader), _payloadHash)) {
            return VerificationState.Verifiable;
        }
        return VerificationState.Verifying;
    }
}
