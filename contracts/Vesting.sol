//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vesting is AccessControl, ReentrancyGuard, Ownable {
    uint256 private constant TIMELOCK = 1 days;
    uint256 private constant MAX_ALLOCATIONS_PER_ADDRESS = 10;
    uint256 private constant CLIFF_PERIOD = 15 days;
    IERC20 public immutable token;

    mapping(address => AllocationData[]) allocations;
    mapping(address => User) users;

    uint256 totalToBeReleased;
    uint256 totalReleased;

    struct AllocationData {
        uint256 period; //sliding period, in seconds; not a timestamp
        uint256 amount;
        bool isReleasedToUser;
        bool isRevoked;

        bool isWithValue;
    }

    struct User {
        uint256 addedAt;
        uint256 totalReleased;
        uint256 totalToBeReleased;
        bool isDisabled;

        bool isWithValue;
    }

    constructor(address _token) {
        token = IERC20(_token);
    }


    /**
     * try to claim tokens
     * @param _to target address or user; only the owner of "_to" address may call this function, otherwise it'll fail
    */
    function claim(address _to) external nonReentrant {
        require(msg.sender == _to, "only the recipient may call it");
        require(users[_to].isWithValue, "recipient doesn't exist in the list of the users");
        require(!users[_to].isDisabled, "user is disabled: can't proceed");

        uint timeDiff = block.timestamp - users[_to].addedAt;
        require(timeDiff > CLIFF_PERIOD, "the cliff period hasn't been passed yet");

        AllocationData[] memory userAlloc = allocations[msg.sender];
        for (uint256 i = 0; i < userAlloc.length; i++) {
            if (userAlloc[i].isWithValue) {
                bool c1 = !userAlloc[i].isRevoked;
                bool c2 = !userAlloc[i].isReleasedToUser;
                if (c1 && c2) {
                    if (timeDiff > userAlloc[i].period) {
                        //vesting time has come; send out tokens to a user

                        uint256 val = userAlloc[i].amount;
                        require(token.balanceOf(address(this)) >= val, "lack of tokens to transfer: can't proceed");

                        bool success = token.transfer(_to, val);
                        require(success, "failed to send out vested tokens to a user");

                        userAlloc[i].isReleasedToUser = true;
                        users[_to].totalReleased += val;
                        users[_to].totalToBeReleased -= val;

                        totalReleased += val;
                        totalToBeReleased -= val;
                    }
                }
            }
        }
    }

    /**
     * adds a new allocation
     * @param _addr target address or user
     * @param _period sliding period, in seconds
     * @param _amount tokens
    */
    function addAllocation(address _addr, uint256 _period, uint256 _amount) external onlyOwner {
        require(users[_addr].isWithValue, "recipient doesn't exist in the list of the users");
        require(!users[_addr].isDisabled, "user is disabled: can't proceed");
        require(_period > CLIFF_PERIOD, "period has to be greater than the cliff period");

        //how long ago the user was created
        uint256 diff = block.timestamp - users[_addr].addedAt;
        require(_period > (diff + TIMELOCK), "period has to be greater than (today + TIMELOCK)");
        require(address(this).balance >= _amount, "lack of tokens to send: can't proceed"); //


        //add new allocation
        AllocationData memory ad;
        ad.period = _period;
        ad.amount = _amount;
        ad.isWithValue = true;
        allocations[_addr].push(ad);

        users[_addr].totalToBeReleased += _amount;
        totalToBeReleased += _amount;
    }

    /**
     * add new user/participant
     * @param _addr address to add
    */
    function addUser(address _addr) external onlyOwner {
        require(!users[_addr].isWithValue, "user already exists");
        require(!users[_addr].isDisabled, "disabled or deleted user may not be re-added");

        User memory usr;
        usr.addedAt = block.timestamp;
        usr.isWithValue = true;
        users[_addr] = usr;
    }

    /**
     * delete a user/participant
     * @param _addr address associated with a user/participant
    */
    function deleteUser(address _addr) external onlyOwner {
        require(users[_addr].isWithValue, "user doesn't exist");
        require(!users[_addr].isDisabled, "user is disabled or deleted");

        users[_addr].isDisabled = true;

        // TODO: optional
        // delete users[_addr];         //it's better to mark it as deleted and not remove it, for the sake of history
        // delete allocations[_addr];   //the same thing: keep it, otherwise there'll be no trace left
    }


    /**
     * get info about a user's allocations, as a tuple 
     * that contains the sum of: (released tokens, to be released tokens)
     * @param _addr target address or user
    */
    function getUserAllocationAmounts(address _addr) external view returns (uint256, uint256) {
        User memory u = users[_addr];

        require(msg.sender == _addr, "only the owner of the address may call it");
        require(u.isWithValue, "user doesn't exist");
        require(!u.isDisabled, "user is disabled: can't proceed");

        return (users[_addr].totalReleased, users[_addr].totalToBeReleased);
    }

    /**
     * get info about all the users' allocations, as a tuple 
     * that contains the sum of: (released tokens, to be released tokens)
    */
    function getTotalAllocationAmounts() external view onlyOwner returns (uint256, uint256) {
        return (totalReleased, totalToBeReleased);
    }

    /**
     * once an allocation(s) has been added to a user's slot of allocations
     * the only way to delete the ones that'll occur in the future
     * is to revoke them, e.g. mark them as 'revoked';
     * once done, the admin may add new allocations again that'll be active
     * @param _to target address or user
    */
    function revokeFurtherAllocations(address _to) external onlyOwner {
        require(msg.sender == _to, "only the recipient may call it");
        require(users[_to].isWithValue, "recipient doesn't exist in the list of the users");

        uint timeDiff = block.timestamp - users[_to].addedAt;
        require(timeDiff > CLIFF_PERIOD, "the cliff period hasn't been passed yet");

        AllocationData[] memory userAlloc = allocations[msg.sender];
        for (uint256 i = 0; i < userAlloc.length; i++) {
            if (userAlloc[i].isWithValue) {
                bool c1 = !userAlloc[i].isRevoked;
                bool c2 = !userAlloc[i].isReleasedToUser;
                if (c1 && c2) {
                    userAlloc[i].isRevoked = true;
                    users[_to].totalToBeReleased -= userAlloc[i].amount;
                    totalToBeReleased -= userAlloc[i].amount;
                }
            }
        }
    }
}