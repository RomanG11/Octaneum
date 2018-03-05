pragma solidity ^0.4.19;

library SafeMath { //standart library for uint
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0){
        return 0;
    }
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function pow(uint256 a, uint256 b) internal pure returns (uint256){ //power function
    if (b == 0){
      return 1;
    }
    uint256 c = a**b;
    assert (c >= a);
    return c;
  }
}

//standart contract to identify owner
contract Ownable {

  address public owner;

  address public newOwner;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function Ownable() public {
    owner = msg.sender;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    require(_newOwner != address(0));
    newOwner = _newOwner;
  }

  function acceptOwnership() public {
    if (msg.sender == newOwner) {
      owner = newOwner;
    }
  }
}

//Abstract Token contract
contract OctaneumToken{
  function setCrowdsaleContract (address) public;
  function sendCrowdsaleTokens(address, uint256)  public;
  function balanceOf(address) public view returns (uint256);
  function burnContriburorTokens(address) public;


}

//Crowdsale contract
contract Crowdsale is Ownable{

  using SafeMath for uint;


  //CHANGE IT
  uint decimals = 8;


  // Token contract address
  OctaneumToken public token;

  // Constructor
  function Crowdsale(address _tokenAddress) public{
    token = OctaneumToken(_tokenAddress);
    owner = msg.sender;

    token.setCrowdsaleContract(this);
  }
  
  //contributors variables
  mapping (address => uint) contributorTokenBought;
  mapping (address => uint) contributorEthSended;
  

  //Crowdsale variables
  uint public preIcoTokensSold = 0;
  uint public icoTokensSold = 0;
  uint public tokensSold = 0;
  uint public ethCollected = 0;

  uint minDeposit = 0.01 ether;

  uint public tokenPrice = 0.001575 ether/((uint)(10).pow(decimals)); //1.5 USD

  // Buy constants
  // uint PreIcotokenPrice = 100000000000000/((uint)(10).pow(decimals));
  // uint icoTokenPrice = 150015000000000/((uint)(10).pow(decimals));

  // PreICO constants
  uint public constant PRE_ICO_START = 0; //23/03/2018  00:01 HNE 1521781260
  uint public constant PRE_ICO_FINISH = 1524545940; // 23/04/2018 23:59 HNE

  // Ico constants
  uint public constant ICO_START = 1524459660; //23/04/2018 00:01 HNE 
  uint public constant ICO_FINISH = 1527137940; //23/05/2018 23:59 HNE 

  // PreICOConstants
  // uint public constant PRE_ICO_MIN_CAP = 1; //CHANGE IT
  uint public constant PRE_ICO_MAX_CAP = (uint)(2000000).mul((uint)(10).pow(decimals)); //CHANGE IT

  // IcoConstants
  //CHANGE it
  uint public constant ICO_MIN_CAP = (uint)(15000000).mul((uint)(10).pow(decimals)); //15 000 000 $
  uint public constant ICO_MAX_CAP = (uint)(33000000).mul((uint)(10).pow(decimals));  //33 000 000 $

  //check is now ICO
  function isPreIco(uint _time) public pure returns (bool){
    if((PRE_ICO_START <= _time) && (_time <= PRE_ICO_FINISH)){
      return true;
    }
    return false;
  }

  //check is now ICO
  function isIco(uint _time) public pure returns (bool){
    if((ICO_START <= _time) && (_time <= ICO_FINISH)){
      return true;
    }
    return false;
  }

  
  //fallback function (when investor send ether to contract)
  function() public payable{
    require(isPreIco(now) || isIco(now));
    require(msg.value >= minDeposit);
    require(buy(msg.sender,msg.value, now)); //redirect to func buy
  }


  //function buy Tokens
  function buy(address _address, uint _value, uint _time) internal returns (bool){
    uint tokensToSend = etherToTokens(_value, _time);

    if (isPreIco(_time)){
      require(preIcoTokensSold.add(tokensToSend) <= PRE_ICO_MAX_CAP);
      preIcoTokensSold = preIcoTokensSold.add(tokensToSend);
      tokensSold = tokensSold.add(tokensToSend);
    }
    if (isIco(_time)){
      require(icoTokensSold.add(tokensToSend) <= ICO_MAX_CAP);
      icoTokensSold = icoTokensSold.add(tokensToSend);
      tokensSold = tokensSold.add(tokensToSend);
    }

    token.sendCrowdsaleTokens(_address, tokensToSend);
    contributorTokenBought[_address] = contributorTokenBought[_address].add(tokensToSend);
    contributorEthSended[_address] = contributorEthSended[_address].add(_value);

    return true;
  }

  //convert ether to tokens
  function etherToTokens(uint _value, uint _time) public view returns(uint res) {
    res = _value/tokenPrice;
    uint bonus = 0;

    if (isPreIco(_time)){
      bonus = preIcoTimeBasedBonus(_time);
    }
    if (isIco(_time)){
      bonus = icoTimeBasedBonus(_time);
    }

    res = res.add(res.mul((uint)(bonus))/100);
  }

  function preIcoTimeBasedBonus(uint _time) public pure returns(uint) {
    if (_time < PRE_ICO_FINISH){
      return 30;
    }
    return 0;
  }
  

  function icoTimeBasedBonus (uint _time) public pure returns(uint) {
    if (_time >= ICO_START){  
      if (_time < ICO_START + 7 days){
       return 25;
      }
      if (_time < ICO_START + 14 days){
        return 20;
      }
      if (_time < ICO_START + 21 days){
        return 15;
      }
      if (_time < ICO_START + 28 days){
        return 10;
      }
      if (_time < ICO_START + 35 days){
        return 5;
      }
    }

    return 0;
  }

  //Distribute ether (value in WEI)
  function ethDistibution (address _address, uint _ether) public onlyOwner{
    require(isIcoTrue());
    _address.transfer(_ether);
  }
  
  function isIcoTrue () public view returns(bool) {
    if(tokensSold >= ICO_MIN_CAP){
      return true;
    }
    return false;
  }
  


  function isIcoAchieved () public view returns(bool) {
    if (ethCollected >= ICO_MIN_CAP){
      return true;
    }
    return false;
  }
  
  function refund() public {
    require(now > ICO_FINISH);
    require(!isIcoTrue());
    require(token.balanceOf(msg.sender) >= contributorTokenBought[msg.sender]);

    token.burnContriburorTokens(msg.sender);
    msg.sender.transfer(contributorEthSended[msg.sender]);
  }
  
 
}