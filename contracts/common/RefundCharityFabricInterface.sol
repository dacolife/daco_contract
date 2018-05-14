pragma solidity ^0.4.23;

import "./RefundCharity.sol";

/**
 * @title RefundCharityFabric
 * @dev RefundCharity is a contract for creating a crowd charity campaign
 */

contract RefundCharityFabricInterface {
  using SafeMath for uint256;

  function create(
    address[] _wallets,
    uint256[] _goals,
    uint256 _closingTime
  ) public returns (RefundCharity);
}
