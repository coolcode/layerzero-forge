// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IRelayer {
    function schedulePacket(bytes calldata _packetBytes, bytes calldata _options) external;
    function verifyPackets(uint32 _dstEid, bytes32 _dstAddress) external;
}
