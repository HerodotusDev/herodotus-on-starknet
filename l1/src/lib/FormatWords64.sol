// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

library FormatWords64 {
    // Convert a bytes32 variable passed as parameter into 4 words of 8 bytes
    // @param input The bytes32 to convert
    // @return word1 The first word of 8 bytes
    // @return word2 The second word of 8 bytes
    // @return word3 The third word of 8 bytes
    // @return word4 The fourth word of 8 bytes
    function fromBytes32(
        bytes32 input
    )
        internal
        pure
        returns (bytes8 word1, bytes8 word2, bytes8 word3, bytes8 word4)
    {
        assembly {
            word1 := input
            word2 := shl(64, input)
            word3 := shl(128, input)
            word4 := shl(192, input)
        }
    }
}
