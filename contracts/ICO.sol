
pragma solidity ^0.4.11;

import "./PreICO.sol";
import "./ATL.sol";
import "./installed/token/ERC20.sol";

contract ICO {

  uint public constant MIN_TOKEN_PRICE = 425; // min atl per ETH
  uint public constant TOKENS_FOR_SALE = 103548812 * 1e18;
  uint public constant ATL_PER_ATP = 2; // Migration rate

  event Buy(address holder, uint atlValue);
  event ForeignBuy(address holder, uint atlValue, string txHash);
  event Migrate(address holder, uint atlValue);
  event RunIco();
  event PauseIco();
  event FinishIco(address teamFund, address bountyFund);

  PreICO preICO;
  ATL public atl;

  address public team;
  address public tradeRobot;
  modifier teamOnly { require(msg.sender == team); _; }
  modifier robotOnly { require(msg.sender == tradeRobot); _; }

  uint tokensSold = 0;

  enum IcoState { Created, Running, Paused, Finished }
  IcoState icoState = IcoState.Created;


  function ICO(address _team, address _preICO, address _tradeRobot) {
    atl = new ATL(this);
    preICO = PreICO(_preICO);
    team = _team;
    tradeRobot = _tradeRobot;
  }


  function() external payable {
    buyFor(msg.sender);
  }


  function buyFor(address _investor) public payable {
    require(icoState == IcoState.Running);
    require(msg.value > 0);
    uint _total = buy(_investor, msg.value * MIN_TOKEN_PRICE);
    Buy(_investor, _total);
  }


  function getBonus(uint _value, uint _sold)
    public constant returns (uint)
  {
    uint[8] memory _bonusPricePattern = [ 505, 495, 485, 475, 465, 455, 445, uint(435) ];
    uint _step = TOKENS_FOR_SALE / 10;
    uint _bonus = 0;

    for (uint8 i = 0; _value > 0 && i < _bonusPricePattern.length; ++i) {
      uint _min = _step * i;
      uint _max = _step * (i+1);

      if (_sold >= _min && _sold < _max) {
        uint bonusedPart = min(_value, _max - _sold);
        _bonus += bonusedPart * _bonusPricePattern[i] / MIN_TOKEN_PRICE - bonusedPart;
        _value -= bonusedPart;
        _sold += bonusedPart;
      }
    }

    return _bonus;
  }

  function foreignBuy(address _investor, uint _atlValue, string _txHash)
    external robotOnly
  {
    require(icoState == IcoState.Running);
    require(_atlValue > 0);
    uint _total = buy(_investor, _atlValue);
    ForeignBuy(_investor, _total, _txHash);
  }


  function setRobot(address _robot) external teamOnly {
    tradeRobot = _robot;
  }


  function migrateSome(address[] _investors) external robotOnly {
    for (uint i = 0; i < _investors.length; i++)
      doMigration(_investors[i]);
  }


  function startIco() external teamOnly {
    require(icoState == IcoState.Created || icoState == IcoState.Paused);
    icoState = IcoState.Running;
    RunIco();
  }


  function pauseIco() external teamOnly {
    require(icoState == IcoState.Running);
    icoState = IcoState.Paused;
    PauseIco();
  }


  function finishIco(
    address _teamFund,
    address _bountyFund
  )
    external teamOnly
  {
    require(icoState == IcoState.Running || icoState == IcoState.Paused);

    atl.mint(_teamFund, 22500000 * 1e18);
    atl.mint(_bountyFund, 18750000 * 1e18);
    atl.unfreeze();

    icoState = IcoState.Finished;
    FinishIco(_teamFund, _bountyFund);
  }


  function withdrawEther(uint _value) external teamOnly {
    team.transfer(_value);
  }


  function withdrawToken(address _tokenContract, uint _val) external teamOnly
  {
    ERC20 _tok = ERC20(_tokenContract);
    _tok.transfer(team, _val);
  }


  function min(uint a, uint b) internal constant returns (uint) {
    return a < b ? a : b;
  }


  function buy(address _investor, uint _atlValue) internal returns (uint) {
    uint _bonus = getBonus(_atlValue, tokensSold);
    uint _total = _atlValue + _bonus;

    require(tokensSold + _total <= TOKENS_FOR_SALE);

    atl.mint(_investor, _total);
    tokensSold += _total;
    return _total;
  }


  function doMigration(address _investor) internal {
    require(icoState != IcoState.Finished);

    uint _atpBalance = preICO.balanceOf(_investor);
    require(_atpBalance > 0);

    preICO.burnTokens(_investor);

    uint _atlValue = _atpBalance * ATL_PER_ATP;
    atl.mint(_investor, _atlValue);

    Migrate(_investor, _atlValue);
  }
}
