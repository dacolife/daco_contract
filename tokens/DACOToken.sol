pragma solidity ^0.4.15;

import "../common/SafeMath.sol";
import "./MintableToken.sol";
import "./KARMAToken.sol";

contract DACOToken is MintableToken {
  string public constant name = "DACO Token";
  string public constant symbol = "DACO";
  uint8 public constant decimals = 18;
  
  function DACOToken() public {

  }
  
  function transfer(address _to, uint256 _value) public returns (bool) {
      require(_to != address(0));
      require(_value <= balances[msg.sender]);

      // SafeMath.sub will throw if there is not enough balance.
      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[_to] = balances[_to].add(_value);
      Transfer(msg.sender, _to, _value);
      return true;
  }
}
