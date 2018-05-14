pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./Ownable.sol";

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a donations
 * is in progress. Supports refunding the money if donations fails,
 * and forwarding it if donation is successful.
 */
contract RefundVault is Ownable {
  using SafeMath for uint256;

  enum State { Active, Refunding, Closed }

  mapping (address => uint256) public deposited;
  address[] public wallets;
  uint256[] public amounts;
  State public state;

  event Closed();
  event RefundsEnabled();
  event Refunded(address indexed beneficiary, uint256 weiAmount);

  /**
   * @param _wallets Vault addresses
   */
  function RefundVault(address[] _wallets, uint256[] _amounts) public {
    require(_wallets.length == _amounts.length);

    for (uint i = 0; i < _wallets.length; i++) {
      require(_wallets[i] != address(0));
      require(_amounts[i] > 0);
    }
    wallets = _wallets;
    amounts = _amounts;
    state = State.Active;
  }

  /**
   * @param investor Investor address
   */
  function deposit(address investor) onlyOwner public payable {
    require(state == State.Active);
    deposited[investor] = deposited[investor].add(msg.value);
  }

  function close() onlyOwner public {
    require(state == State.Active);
    state = State.Closed;
    emit Closed();
    for (uint i = 0; i < wallets.length; i++) {
      wallets[i].send(amounts[i]);
    }
  }

  function enableRefunds() onlyOwner public {
    require(state == State.Active);
    state = State.Refunding;
    emit RefundsEnabled();
  }

  /**
   * @param investor Investor address
   */
  function refund(address investor) public {
    require(state == State.Refunding);
    uint256 depositedValue = deposited[investor];
    deposited[investor] = 0;
    investor.transfer(depositedValue);
    emit Refunded(investor, depositedValue);
  }
}

/**
 * @title RefundCharity
 * @dev RefundCharity is a contract for managing a crowd charity campaign
 */

contract RefundCharity is Ownable {
  using SafeMath for uint256;

  // Address where funds are collected
  address[] public wallets;

  // amount of funds to be raised in weis for wallets
  uint256[] public goals;

  // amount of funds to be raised in weis
  uint256 public goal;

  // refund vault used to hold funds while donations is running
  RefundVault public vault;

  // Amount of wei raised
  uint256 public weiRaised;

  uint256 public openingTime;
  uint256 public closingTime;

  bool public isFinalized = false;

  event Finalized();

  /**
   * Event for donate logging
   * @param purchaser who paid
   * @param value weis paid for purchase
   */
  event Donate(address indexed purchaser, uint256 value);

  /**
   * @dev Reverts if not in donations time range.
   */
  modifier onlyWhileOpen {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime);
    _;
  }

  // -----------------------------------------
  // External interface
  // -----------------------------------------

  /**
   * @dev fallback function ***DO NOT OVERRIDE***
   */
  function () external payable {
    donate(msg.sender);
  }

  /**
   * @dev low level donations ***DO NOT OVERRIDE***
   * @param _beneficiary Address who make donation
   */
  function donate(address _beneficiary) public payable {

    uint256 weiAmount = msg.value;

    uint256 change = 0;
    uint256 needed = goal.sub(weiRaised);

    if (weiAmount > needed) {
      change = weiAmount.sub(needed);
      weiAmount = needed;
    }

    if (change > 0) {
      _beneficiary.transfer(change);
    }

    _preValidatePurchase(_beneficiary, weiAmount);

    // update state
    weiRaised = weiRaised.add(weiAmount);

    emit Donate(msg.sender, weiAmount);

    _forwardFunds(weiAmount);
    _postValidatePurchase(_beneficiary, weiAmount);
  }

  // -----------------------------------------
  // Internal interface (extensible)
  // -----------------------------------------

  /**
   * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
   * @param _beneficiary Address performing the donation
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal onlyWhileOpen {
    require(_beneficiary != address(0));
    require(_weiAmount != 0);
    require(weiRaised.add(_weiAmount) <= goal);
  }

  /**
   * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
   * @param _beneficiary Address performing the donation
   * @param _weiAmount Value in wei involved in the purchase
   */
  function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
    // optional override
  }

  /**
   * @dev Determines how ETH is stored/forwarded - sending funds to vault.
   */
  function _forwardFunds(uint256 _weiAmount) internal {
    vault.deposit.value(_weiAmount)(msg.sender);
  }

  /**
   * @dev Checks whether the period in which the donations is open has already elapsed.
   * @return Whether donations period has elapsed
   */
  function hasClosed() public view returns (bool) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp > closingTime;
  }

  /**
   * @dev Checks whether the goal has been reached.
   * @return Whether the goal was reached
   */
  function goalReached() public view returns (bool) {
    return weiRaised >= goal;
  }

  /**
   * @param _wallets Address where collected funds will be forwarded to
   * @param _goals Donations goal
   * @param _closingTime Donation closing time
   */
  function RefundCharity(
    address[] _wallets,
    uint256[] _goals,
    uint256 _closingTime
  )
  public
  {
    require(_wallets.length == _goals.length);

    for (uint i = 0; i < _wallets.length; i++) {
      require(_wallets[i] != 0x0);
      require(_goals[i] > 0);
      goal = goal.add(_goals[i]);
    }

    require(_closingTime >= block.timestamp);

    wallets = _wallets;

    openingTime = now;
    closingTime = _closingTime;

    vault = new RefundVault(_wallets, _goals);
    goals = _goals;
  }

  /**
   * @dev Must be called after campaign ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() public {
    require(!isFinalized);
    require(hasClosed() || goalReached());

    finalization();
    emit Finalized();

    isFinalized = true;
  }

  /**
   * @dev Donators can claim refunds here if donations is unsuccessful
   */
  function claimRefund() public {
    require(isFinalized);
    require(!goalReached());

    vault.refund(msg.sender);
  }

  /**
   * @dev vault finalization task, called when owner calls finalize()
   */
  function finalization() internal {
    if (goalReached()) {
      vault.close();
    } else {
      vault.enableRefunds();
    }
  }
}
