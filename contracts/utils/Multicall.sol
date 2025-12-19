// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Multicall {
    struct Call {
        address target;
        bytes callData;
    }

    function aggregate(Call[] memory calls) public view returns (bytes[] memory returnData) {
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            if (calls[i].callData.length > 0) {
                (, bytes memory ret) = calls[i].target.staticcall(calls[i].callData);
                returnData[i] = ret;
            } else {
                returnData[i] = abi.encode(calls[i].target.balance);
            }
        }
    }
}
