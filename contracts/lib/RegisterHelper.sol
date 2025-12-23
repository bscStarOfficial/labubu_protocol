// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract RegisterHelper {
    address public constant ROOT_USER = address(1);
    mapping(address => address) public referrers;
    mapping(address => address[]) public referrals;

    function registerInternal(address referral, address referrer) internal virtual {
        // if (registered(referral)) return;

        require(!registered(referral), "registered");
        require(registered(referrer), "referrer does not existed");

        referrers[referral] = referrer;
        referrals[referrer].push(referral);

//        emit Registered(referral, referrer);
    }

    function registered(address user) public view returns (bool) {
        return user == ROOT_USER || referrers[user] != address(0);
    }

    function getReferrals(address user) public view returns (address[] memory){
        return referrals[user];
    }

    function getReferrers(address user, uint count) public view returns (address[] memory _referrers, uint realCount) {
        _referrers = new address[](count);
        for (uint i = 0; i < count; i++) {
            _referrers[i] = referrers[user];
            user = _referrers[i];
            if(user == ROOT_USER || user == address(0)) break;
            realCount++;
        }
    }

    function getUnderReferralCount(address user) public view returns (uint count){
        count = referrals[user].length;
        for (uint i = 0; i< referrals[user].length; i++) {
            count += getUnderReferralCount(referrals[user][i]);
        }
    }

}
