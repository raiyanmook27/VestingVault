// SPDX-License-Identifier: MIT
pragma solidity  0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error VV__onlyBeneficiary();
error VV__UnlockTimeNotElapsed();
contract VestingVault is Ownable{

    using SafeERC20 for IERC20;

    address immutable private beneficiary;
    uint64 private s_unlockTime;
    uint64 private s_cliff;
    uint64 public immutable i_MAX_PERIOD;
    mapping(address=>uint256) private s_tokenReleased;
    mapping(address=>bool)private  s_tokenFunded;
    bool private isCliff;

    modifier onlyBeneficiary(){
        if(_msgSender()!=beneficiary){
            revert VV__onlyBeneficiary();
        }
        _;
    }

    constructor(address _beneficiary,uint64 maxPeriod){
        require(_beneficiary !=address(0));
        beneficiary =_beneficiary;
        i_MAX_PERIOD = maxPeriod;
    }

     receive() external payable  {}


     function getBalance(address _token) public view returns(uint256){
         return IERC20(_token).balanceOf(address(this));
     }
  

    function fundTokens(address _token,uint _amount, uint64 _unlockTime,bool _isCliff) public payable onlyOwner{
        // one time fund.
        require(!(tokenFunded(_token)),"Already funded");
        // check balance of token
        require(IERC20(_token).balanceOf(owner())>_amount,"Not Enough Funds");
        IERC20(_token).safeTransferFrom(owner(),address(this),_amount);
        
        s_unlockTime = _unlockTime;
        s_tokenFunded[_token] = true;
        isCliff = _isCliff;

    }

    function setCliff(uint64 _cliff)public {
        s_cliff= _cliff;
    }

    function timeStamp()public view returns(uint64){
        return uint64(block.timestamp);
    }

    

    function WithdrawTokens(address _token) public payable onlyBeneficiary{
       uint256 releasable = _vest(_token) - tokenReleased(_token);
        s_tokenReleased[_token] += releasable;
        IERC20(_token).safeTransfer(_msgSender(),releasable);
    }

    function _vest(address token) public view returns(uint256){
        uint256 tokensReleased = tokenReleased(token);
        uint64 cliff = s_cliff;
        if(isCliff){
            return _vestingSchedule(IERC20(token).balanceOf(address(this)) + tokensReleased, uint64(block.timestamp));

        }else{
           return _vestingSchedule(IERC20(token).balanceOf(address(this)) + tokensReleased, uint64(block.timestamp)+cliff);
           
        }
    }


    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        uint64 _unlock = unlockTime(); //gas saving
        if (timestamp < _unlock) {
            revert VV__UnlockTimeNotElapsed();
        } else if (timestamp > _unlock + i_MAX_PERIOD) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - _unlock)) / i_MAX_PERIOD;
        }
    }

    function unlockTime() public view returns(uint64){
        return s_unlockTime;
    }

    function tokenReleased(address _token) public view returns(uint256){
        return s_tokenReleased[_token];
    }

    function tokenFunded(address _token) public view returns(bool){
        return s_tokenFunded[_token];
    }
}
