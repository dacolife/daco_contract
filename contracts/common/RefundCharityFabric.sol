pragma solidity ^0.4.23;

import "./RefundCharity.sol";

/**
 * @title RefundCharityFabric
 * @dev RefundCharity is a contract for creating a crowd charity campaign
 */

contract RefundCharityFabric {
  using SafeMath for uint256;

  function create(
    address[] _wallets,
    uint256[] _goals,
    uint256 _closingTime
  ) public returns (address newAddr) {
    RefundCharity newContract = new RefundCharity(_wallets, _goals, _closingTime);

    return newContract;
  }
}
