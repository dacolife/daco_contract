pragma solidity ^0.4.15;

import "./math.sol";
import "./token.sol";

/**
 * @title RefundVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it if crowdsale is successful.
 */
contract RefundVault is Ownable {
  using SafeMath for uint256;

    enum State { Active, Refunding, Closed }

  mapping (address => uint256) public deposited;
  address public wallet;
  State public state;

  event Closed();
  event RefundsEnabled();
  event Refunded(address indexed beneficiary, uint256 weiAmount);

  function RefundVault(address _wallet) {
    require(_wallet != 0x0);
    wallet = _wallet;
    state = State.Active;
  }

  function deposit(address investor) onlyOwner public payable {
    require(state == State.Active);
    deposited[investor] = deposited[investor].add(msg.value);
  }

  function close() onlyOwner public {
    require(state == State.Active);
    state = State.Closed;
    Closed();
    wallet.transfer(this.balance);
  }

  function enableRefunds() onlyOwner public {
    require(state == State.Active);
    state = State.Refunding;
    RefundsEnabled();
  }

  function refund(address investor) public {
    require(state == State.Refunding);
    uint256 depositedValue = deposited[investor];
    deposited[investor] = 0;
    investor.transfer(depositedValue);
    Refunded(investor, depositedValue);
  }
}


/**
 * @title Crowdsale
 * @dev Modified contract for managing a token crowdsale.
 * DACOTokenCrowdsale have pre-sale and main sale periods, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate and the system of bonuses.
 * Funds collected are forwarded to a wallet as they arrive.
 * pre-sale and main sale periods both have caps defined in tokens
 */

contract DACOTokenCrowdsale is Ownable {

  using SafeMath for uint256;

                     struct Bonus {
    uint bonusEndTime;
    uint timePercent;
    uint bonusMinAmount;
    uint amountPercent;
  }

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // wel token emission
  uint256 public tokenEmission;

  // refund vault used to hold funds while crowdsale is running
  RefundVault public vault;

  // true for finalised crowdsale
  bool public isFinalized;

  // The token being sold
  MintableToken public token;

  // start and end timestamps where pre-investments are allowed (both inclusive)
  uint256 public preSaleStartTime;
  uint256 public preSaleEndTime;

  // start and end timestamps where main-investments are allowed (both inclusive)
  uint256 public mainSaleStartTime;
  uint256 public mainSaleEndTime;

  // maximum amout of wei for pre-sale and main sale
  uint256 public preSaleWeiCap;
  uint256 public mainSaleWeiCap;

  // address where funds are collected
  address public wallet;

  // address where final 10% of funds will be collected
  address public tokenWallet;

  // how many token units a buyer gets per wei
  uint256 public rate;

  // amount of raised money in wei
  uint256 public weiRaised;

  Bonus[] public preSaleBonuses;
  Bonus[] public mainSaleBonuses;

  uint256 public preSaleMinimumWei;
  uint256 public mainSaleMinimumWei;

  uint256 public defaultPercent;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event FinalisedCrowdsale(uint256 totalSupply, uint256 minterBenefit);

  function DACOTokenCrowdsale(uint256 _preSaleStartTime, uint256 _preSaleEndTime, uint256 _preSaleWeiCap, uint256 _mainSaleStartTime, uint256 _mainSaleEndTime, uint256 _mainSaleWeiCap, uint256 _goal, uint256 _rate, address _wallet, address _tokenWallet) public {

    //require(_goal > 0);

    // can't start pre-sale in the past
    require(_preSaleStartTime >= now);

    // can't start main sale in the past
    require(_mainSaleStartTime >= now);

    // can't start main sale before the end of pre-sale
    require(_preSaleEndTime < _mainSaleStartTime);

    // the end of pre-sale can't happen before it's start
    require(_preSaleStartTime < _preSaleEndTime);

    // the end of main sale can't happen before it's start
    require(_mainSaleStartTime < _mainSaleEndTime);

    require(_rate > 0);
    require(_preSaleWeiCap > 0);
    require(_mainSaleWeiCap > 0);
    require(_wallet != 0x0);
    require(_tokenWallet != 0x0);

    preSaleMinimumWei = 300000000000000000;  // 0.3 Ether default minimum
    mainSaleMinimumWei = 300000000000000000; // 0.3 Ether default minimum
    defaultPercent = 0;

    tokenEmission = 150000000 ether;

    preSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 2, timePercent: 20, bonusMinAmount: 8500 ether, amountPercent: 25}));
    preSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 4, timePercent: 20, bonusMinAmount: 0, amountPercent: 0}));
    preSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 6, timePercent: 15, bonusMinAmount: 0, amountPercent: 0}));
    preSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 7, timePercent: 10, bonusMinAmount: 20000 ether, amountPercent: 15}));

    mainSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 7,  timePercent: 9, bonusMinAmount: 0, amountPercent: 0}));
    mainSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 14, timePercent: 6, bonusMinAmount: 0, amountPercent: 0}));
    mainSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 21, timePercent: 4, bonusMinAmount: 0, amountPercent: 0}));
    mainSaleBonuses.push(Bonus({bonusEndTime: 3600 * 24 * 28, timePercent: 0, bonusMinAmount: 0, amountPercent: 0}));

    preSaleStartTime = _preSaleStartTime;
    preSaleEndTime = _preSaleEndTime;
    preSaleWeiCap = _preSaleWeiCap;
    mainSaleStartTime = _mainSaleStartTime;
    mainSaleEndTime = _mainSaleEndTime;
    mainSaleWeiCap = _mainSaleWeiCap;
    goal = _goal;
    rate = _rate;
    wallet = _wallet;
    tokenWallet = _tokenWallet;

    isFinalized = false;

    token = new DACOToken();
    vault = new RefundVault(wallet);
  }

  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {

    require(beneficiary != 0x0);
    require(msg.value != 0);
    require(!isFinalized);

    uint256 weiAmount = msg.value;

    validateWithinPeriods();
    validateWithinCaps(weiAmount);

    // calculate token amount to be created
    uint256 tokens = weiAmount.mul(rate);

    uint256 percent = getBonusPercent(tokens, now);

    // add bonus to tokens depends on the period
    uint256 bonusedTokens = applyBonus(tokens, percent);

    // update state
    weiRaised = weiRaised.add(weiAmount);
    token.mint(beneficiary, bonusedTokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, bonusedTokens);

    forwardFunds();
  }

  // owner can mint tokens during crowdsale withing defined caps
  function mintTokens(address beneficiary, uint256 weiAmount, uint256 forcePercent) external onlyOwner returns (bool) {

    require(forcePercent <= 100);
    require(beneficiary != 0x0);
    require(weiAmount != 0);
    require(!isFinalized);

    validateWithinCaps(weiAmount);

    uint256 percent = 0;

    // calculate token amount to be created
    uint256 tokens = weiAmount.mul(rate);

    if (forcePercent == 0) {
      percent = getBonusPercent(tokens, now);
    } else {
      percent = forcePercent;
    }

    // add bonus to tokens depends on the period
    uint256 bonusedTokens = applyBonus(tokens, percent);

    // update state
    weiRaised = weiRaised.add(weiAmount);
    token.mint(beneficiary, bonusedTokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, bonusedTokens);
  }

  // set new dates for pre-salev (emergency case)
  function setPreSaleParameters(uint256 _preSaleStartTime, uint256 _preSaleEndTime, uint256 _preSaleWeiCap, uint256 _preSaleMinimumWei) public onlyOwner {
    require(!isFinalized);
    require(_preSaleStartTime < _preSaleEndTime);
    require(_preSaleWeiCap > 0);
    preSaleStartTime = _preSaleStartTime;
    preSaleEndTime = _preSaleEndTime;
    preSaleWeiCap = _preSaleWeiCap;
    preSaleMinimumWei = _preSaleMinimumWei;
  }

  // set new dates for main-sale (emergency case)
  function setMainSaleParameters(uint256 _mainSaleStartTime, uint256 _mainSaleEndTime, uint256 _mainSaleWeiCap, uint256 _mainSaleMinimumWei) public onlyOwner {
    require(!isFinalized);
    require(_mainSaleStartTime < _mainSaleEndTime);
    require(_mainSaleWeiCap > 0);
    mainSaleStartTime = _mainSaleStartTime;
    mainSaleEndTime = _mainSaleEndTime;
    mainSaleWeiCap = _mainSaleWeiCap;
    mainSaleMinimumWei = _mainSaleMinimumWei;
  }

  // set new wallets (emergency case)
  function setWallets(address _wallet, address _tokenWallet) public onlyOwner {
    require(!isFinalized);
    require(_wallet != 0x0);
    require(_tokenWallet != 0x0);
    wallet = _wallet;
    tokenWallet = _tokenWallet;
  }

  // set new rate (emergency case)
  function setRate(uint256 _rate) public onlyOwner {
    require(!isFinalized);
    require(_rate > 0);
    rate = _rate;
  }

  // set new goal (emergency case)
  function setGoal(uint256 _goal) public onlyOwner {
    require(!isFinalized);
    require(_goal > 0);
    goal = _goal;
  }


  // set token on pause
  function pauseToken() external onlyOwner {
    require(!isFinalized);
    DACOToken(token).pause();
  }

  // unset token's pause
  function unpauseToken() external onlyOwner {
    DACOToken(token).unpause();
  }

  // set token Ownership
  function transferTokenOwnership(address newOwner) external onlyOwner {
    DACOToken(token).transferOwnership(newOwner);
  }

  // @return true if main sale event has ended
  function mainSaleHasEnded() external constant returns (bool) {
    return now > mainSaleEndTime;
  }

  // @return true if pre sale event has ended
  function preSaleHasEnded() external constant returns (bool) {
    return now > preSaleEndTime;
  }

  // send ether to the fund collection wallet
  function forwardFunds() internal {
    //wallet.transfer(msg.value);
    vault.deposit.value(msg.value)(msg.sender);
  }

  // we want to be able to check all bonuses in already deployed contract
  // that's why we pass currentTime as a parameter instead of using "now"
  function getBonusPercent(uint256 tokens, uint256 currentTime) public constant returns (uint256 percent) {
    //require(currentTime >= preSaleStartTime);
    uint i = 0;
    bool isPreSale = currentTime >= preSaleStartTime && currentTime <= preSaleEndTime;
    if (isPreSale) {
      uint256 preSaleDiffInSeconds = currentTime.sub(preSaleStartTime);
      for (i = 0; i < preSaleBonuses.length; i++) {
        if (preSaleDiffInSeconds <= preSaleBonuses[i].bonusEndTime) {
          if (preSaleBonuses[i].bonusMinAmount > 0 && tokens >= preSaleBonuses[i].bonusMinAmount) {
            return preSaleBonuses[i].amountPercent;
          } else {
            return preSaleBonuses[i].timePercent;
          }
        }
      }
    } else {
      uint256 mainSaleDiffInSeconds = currentTime.sub(mainSaleStartTime);
      for (i = 0; i < mainSaleBonuses.length; i++) {
        if (mainSaleDiffInSeconds <= mainSaleBonuses[i].bonusEndTime) {
          if (mainSaleBonuses[i].bonusMinAmount > 0 && tokens >= mainSaleBonuses[i].bonusMinAmount) {
            return mainSaleBonuses[i].amountPercent;
          } else {
            return mainSaleBonuses[i].timePercent;
          }
        }
      }
    }
    return defaultPercent;
  }

  function applyBonus(uint256 tokens, uint256 percent) internal constant returns (uint256 bonusedTokens) {
    uint256 tokensToAdd = tokens.mul(percent).div(100);
    return tokens.add(tokensToAdd);
  }

  function validateWithinPeriods() internal constant {
    // within pre-sale or main sale
    require((now >= preSaleStartTime && now <= preSaleEndTime) || (now >= mainSaleStartTime && now <= mainSaleEndTime));
  }

  function validateWithinCaps(uint256 weiAmount) internal constant {
    uint256 expectedWeiRaised = weiRaised.add(weiAmount);

    // within pre-sale
    if (now >= preSaleStartTime && now <= preSaleEndTime) {
      require(weiAmount >= preSaleMinimumWei);
      require(expectedWeiRaised <= preSaleWeiCap);
    }

    // within main sale
    if (now >= mainSaleStartTime && now <= mainSaleEndTime) {
      require(expectedWeiRaised <= mainSaleWeiCap);
    }
  }

  // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() public {
    require(isFinalized);
    require(!goalReached());
    vault.refund(msg.sender);
  }

  function goalReached() public constant returns (bool) {
    return weiRaised >= goal;
  }

  // finish crowdsale,
  // take totalSupply as 90% and mint 10% more to specified owner's wallet
  // then stop minting forever

  function finaliseCrowdsale() external onlyOwner returns (bool) {
    require(!isFinalized);
    uint256 totalSupply = token.totalSupply();
    uint256 minterBenefit = tokenEmission.sub(totalSupply);
    if (goalReached()) {
      token.mint(tokenWallet, minterBenefit);
      vault.close();
      //token.finishMinting();
    } else {
      vault.enableRefunds();
    }

    FinalisedCrowdsale(totalSupply, minterBenefit);
    isFinalized = true;
    return true;
  }

}