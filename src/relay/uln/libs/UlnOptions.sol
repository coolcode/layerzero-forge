// SPDX-License-Identifier: LZBL-1.2

pragma solidity ^0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { ExecutorOptions } from "../../libs/ExecutorOptions.sol";

import { DVNOptions } from "./DVNOptions.sol";

library UlnOptions {
    using SafeCast for uint256;

    // uint16 internal constant TYPE_1 = 1; // legacy options type 1
    // uint16 internal constant TYPE_2 = 2; // legacy options type 2
    // uint16 internal constant TYPE_3 = 3;

    error InvalidWorkerOptions(uint256 cursor);
    error InvalidWorkerId(uint8 workerId);
    error InvalidLegacyType1Option();
    error InvalidLegacyType2Option();
    error UnsupportedOptionType(uint16 optionType);

    /// @dev decode the options into executorOptions and dvnOptions
    /// @param _options the options can be either legacy options (type 1 or 2) or type 3 options
    /// @return executorOptions the executor options, share the same format of type 3 options
    /// @return dvnOptions the dvn options, share the same format of type 3 options
    function decode(bytes calldata _options)
        internal
        pure
        returns (bytes memory executorOptions, bytes memory dvnOptions)
    {
        // at least 2 bytes for the option type, but can have no options
        if (_options.length < 2) revert InvalidWorkerOptions(0);

        // uint16 optionsType = uint16(bytes2(_options[0:2]));
        uint256 cursor = 2;

        // type3 options: [worker_option][worker_option]...
        // worker_option: [worker_id][option_size][option]
        // worker_id: uint8, option_size: uint16, option: bytes

        unchecked {
            uint256 start = cursor;
            uint8 lastWorkerId; // worker_id starts from 1, so 0 is an invalid worker_id

            // heuristic: we assume that the options are mostly EXECUTOR options only
            // checking the workerID can reduce gas usage for most cases
            while (cursor < _options.length) {
                uint8 workerId = uint8(bytes1(_options[cursor:cursor + 1]));
                if (workerId == 0) revert InvalidWorkerId(0);

                // workerId must equal to the lastWorkerId for the first option
                // so it is always skipped in the first option
                // this operation slices out options whenever the the scan finds a different workerId
                if (lastWorkerId == 0) {
                    lastWorkerId = workerId;
                } else if (workerId != lastWorkerId) {
                    bytes calldata op = _options[start:cursor]; // slice out the last worker's options
                    (executorOptions, dvnOptions) = _insertWorkerOptions(executorOptions, dvnOptions, lastWorkerId, op);

                    // reset the start cursor and lastWorkerId
                    start = cursor;
                    lastWorkerId = workerId;
                }

                ++cursor; // for workerId

                uint16 size = uint16(bytes2(_options[cursor:cursor + 2]));
                if (size == 0) revert InvalidWorkerOptions(cursor);
                cursor += size + 2;
            }

            // the options length must be the same as the cursor at the end
            if (cursor != _options.length) revert InvalidWorkerOptions(cursor);

            // if we have reached the end of the options and the options are not empty
            // we need to process the last worker's options
            if (_options.length > 2) {
                bytes calldata op = _options[start:cursor];
                (executorOptions, dvnOptions) = _insertWorkerOptions(executorOptions, dvnOptions, lastWorkerId, op);
            }
        }
    }

    function _insertWorkerOptions(
        bytes memory _executorOptions,
        bytes memory _dvnOptions,
        uint8 _workerId,
        bytes calldata _newOptions
    ) private pure returns (bytes memory, bytes memory) {
        if (_workerId == ExecutorOptions.WORKER_ID) {
            _executorOptions =
                _executorOptions.length == 0 ? _newOptions : abi.encodePacked(_executorOptions, _newOptions);
        } else if (_workerId == DVNOptions.WORKER_ID) {
            _dvnOptions = _dvnOptions.length == 0 ? _newOptions : abi.encodePacked(_dvnOptions, _newOptions);
        } else {
            revert InvalidWorkerId(_workerId);
        }
        return (_executorOptions, _dvnOptions);
    }
}
