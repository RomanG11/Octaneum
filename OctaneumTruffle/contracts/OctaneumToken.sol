pragma solidity ^0.4.19;

library SafeMath { //standard library for uint
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0){
        return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
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

 /*
 * Contract that is working with ERC223 tokens
 */
 
 contract ContractReceiver {
     
    struct TKN {
        address sender;
        uint value;
        bytes data;
        bytes4 sig;
    }
    
    
    function tokenFallback(address _from, uint _value, bytes _data) public pure {
      TKN memory tkn;
      tkn.sender = _from;
      tkn.value = _value;
      tkn.data = _data;
      uint32 u = uint32(_data[3]) + (uint32(_data[2]) << 8) + (uint32(_data[1]) << 16) + (uint32(_data[0]) << 24);
      tkn.sig = bytes4(u);
      
      /* tkn variable is analogue of msg variable of Ether transaction
      *  tkn.sender is person who initiated this token transaction   (analogue of msg.sender)
      *  tkn.value the number of tokens that were sent   (analogue of msg.value)
      *  tkn.data is data of token transaction   (analogue of msg.data)
      *  tkn.sig is 4 bytes signature of function
      *  if data of token transaction is a function execution
      */
    }
}

//standard contract to identify owner
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

 /* New ERC23 contract interface */
 
contract ERC223 {
//   uint public totalSupply;
  function balanceOf(address who) public view returns (uint);
  
//   function name() public view returns (string _name);
//   function symbol() public view returns (string _symbol);
//   function decimals() public view returns (uint8 _decimals);
//   function totalSupply() public view returns (uint256 _supply);

  function transfer(address to, uint value) public returns (bool ok);
  function transfer(address to, uint value, bytes data) public returns (bool ok);
  function transfer(address to, uint value, bytes data, string custom_fallback) public returns (bool ok);
  
  event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}

//ERC223 token contract
contract OctaneumToken is Ownable, ERC223 {
  using SafeMath for uint;
  // Triggered when tokens are transferred.
  event Transfer(address indexed _from, address indexed _to, uint256 _value);

  // Triggered whenever approve(address _spender, uint256 _value) is called.
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  string public constant symbol = "OCT";
  string public constant name = "Octaneum";

  //change it
  uint8 public constant decimals = 8;


  uint256 _totalSupply = (uint)(100000000).mul((uint)(10).pow(decimals));

  // Owner of this contract
  address public owner;

  // Balances for each account
  mapping(address => uint256) balances;

  // Owner of account approves the transfer of an amount to another account
  mapping(address => mapping (address => uint256)) allowed;

  //standard ERC-20 function
  function totalSupply() public view returns (uint256) { 
    return _totalSupply;
  }

  //standard ERC-20 function
  function balanceOf(address _address) public view returns (uint256 balance) {
    return balances[_address];
  }

  address public crowdsaleContract;

  function setCrowdsaleContract (address _address) public{
    require(crowdsaleContract == address(0));

    crowdsaleContract = _address;
  }

  function sendCrowdsaleTokens (address _to, uint _value) public {
    require(msg.sender == crowdsaleContract);
    bytes memory empty;
    if (isContract(_to)){
      balances[this] = balances[this].sub(_value);
      balances[_to] = balances[_to].add(_value);
      ContractReceiver receiver = ContractReceiver(_to);
      
      receiver.tokenFallback(this, _value, empty);
      Transfer(this, _to, _value, empty);
      Transfer(this,_to,_value); 
    }else{
      balances[this] = balances[this].sub(_value);
      balances[_to] = balances[_to].add(_value);
      Transfer(this, _to, _value, empty);
      Transfer(this,_to,_value); 
    }  
  }


  //ERC-223 standard functions

  // Function that is called when a user or another contract wants to transfer funds .
  function transfer(address _to, uint _value, bytes _data, string _custom_fallback) public returns (bool success) {      
    if (isContract(_to)) {
      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[_to] = balances[_to].add(_value);
      assert(_to.call.value(0)(bytes4(keccak256(_custom_fallback)), msg.sender, _value, _data));
      Transfer(msg.sender, _to, _value, _data);
      Transfer(msg.sender, _to, _value); 
      return true;
    } else {
      return transferToAddress(_to, _value, _data);
    }
  }
  
  // Function that is called when a user or another contract wants to transfer funds .
  function transfer(address _to, uint _value, bytes _data) public returns (bool success) {
        
    if (isContract(_to)) {
        return transferToContract(_to, _value, _data);
    } else {
        return transferToAddress(_to, _value, _data);
    }
  }

  // Standard function transfer similar to ERC20 transfer with no _data .
  // Added due to backwards compatibility reasons .

  function transfer(address _to, uint _value) public returns (bool success) {    
    //standard function transfer similar to ERC20 transfer with no _data
    //added due to backwards compatibility reasons
    bytes memory empty;
    if (isContract(_to)) {
      return transferToContract(_to, _value, empty);
    } else {
      return transferToAddress(_to, _value, empty);
    }
  }
    
    //assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) private view returns (bool is_contract) {
    uint length;
    assembly {
        //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
    return (length>0);
  }
    
    //function that is called when transaction target is an address
  function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[_to] = balances[_to].add(_value);
      Transfer(msg.sender, _to, _value, _data);
      Transfer(msg.sender,_to,_value); 
      return true;
    }
    
    //function that is called when transaction target is a contract
  function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    ContractReceiver receiver = ContractReceiver(_to);
    receiver.tokenFallback(msg.sender, _value, _data);
    Transfer(msg.sender, _to, _value, _data);
    Transfer(msg.sender,_to,_value); 
    return true;
  }

  //END Standard

  //Constructor
  function OctaneumToken() public {
    owner = msg.sender;

    balances[teamAddress] = teamBalance;
    balances[advisorsAddress] = advisorsBalance;
    balances[developersAddress] = developersleBalance;
    balances[OCIAddress] = OCIBalance;

    balances[this] = crowdsaleBalance;

    Transfer(this, teamAddress, teamBalance);
    Transfer(this, advisorsAddress, advisorsBalance);
    Transfer(this, developersAddress, developersleBalance);
    Transfer(this, OCIAddress, OCIBalance);
  }

  uint crowdsaleBalance = (uint)(22000000).mul((uint)(10).pow(decimals));
  uint teamBalance = (uint)(13000000).mul((uint)(10).pow(decimals));
  uint advisorsBalance = (uint)(1000000).mul((uint)(10).pow(decimals));
  uint developersleBalance = (uint)(5000000).mul((uint)(10).pow(decimals));
  uint OCIBalance = (uint)(50000000).mul((uint)(10).pow(decimals));


  //make it constant or add into Constructor?
  address teamAddress = 0x1;
  address advisorsAddress = 0x2;
  address developersAddress = 0x3;
  address OCIAddress = 0xBBBBaAeDaa53EACF57213b95cc023f668eDbA361;

  //functions for refund

  function burnContriburorTokens(address _address) public{
    require(msg.sender == crowdsaleContract);
    _totalSupply = _totalSupply.sub(balances[_address]);
    Transfer(_address,0,balances[_address]);

    balances[_address] = 0;
  }
  
}