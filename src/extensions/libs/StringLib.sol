// SPDX-License-Identifier: LZBL-1.2

pragma solidity ^0.8.0;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

library StringLib {
    function toHex(bytes calldata buffer) public pure returns (string memory) {
        bytes memory converted = new bytes(buffer.length * 2);

        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", converted));
    }

    function toHex(bytes32 buffer) external pure returns (string memory) {
        return Strings.toHexString(uint256(buffer));
    }
}
