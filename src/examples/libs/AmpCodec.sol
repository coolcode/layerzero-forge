// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AmpCodec {
    uint8 internal constant RAW = 0;
    uint8 internal constant ERC20 = 1;

    uint8 internal constant MSG_TYPE_OFFSET = 0;
    // 1-20 (20 bytes): receiver address
    uint8 internal constant RECEIVER_OFFSET = 1;
    // 21-52 (32 bytes): value
    uint8 internal constant VALUE_OFFSET = 21;
    // 53-92 (20*2 bytes): token pair (srcToken <-> dstToken)
    uint8 internal constant TOKEN_OFFSET = 53;
    // 4... byte: body message
    uint8 internal constant BODY_OFFSET = 21;

    function encode(address _receiver, string calldata _msg) external pure returns (bytes memory) {
        return abi.encodePacked(RAW, _receiver, _msg);
    }

    function encode(address _receiver, uint256 _value, address _srcToken, address _dstToken)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(ERC20, _receiver, _value, _srcToken, _dstToken);
    }

    function msgType(bytes calldata _message) internal pure returns (uint8) {
        return uint8(bytes1(_message[MSG_TYPE_OFFSET:RECEIVER_OFFSET]));
    }

    function receiver(bytes calldata _message) internal pure returns (address) {
        return toAddress(_message, RECEIVER_OFFSET);
    }

    function value(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[VALUE_OFFSET:TOKEN_OFFSET]));
    }

    function tokenPair(bytes calldata _message) internal pure returns (address, address) {
        return (toAddress(_message, TOKEN_OFFSET), toAddress(_message, TOKEN_OFFSET + 20));
    }

    function body(bytes calldata _message) internal pure returns (bytes memory) {
        return _message[BODY_OFFSET:];
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }
}
