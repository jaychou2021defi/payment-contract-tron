// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Initializable.sol";
import "./OwnableUpgradeable.sol";
import "./IMerchant.sol";
import "./TransferHelper.sol";
import "./Address.sol";
import "./SafeMath.sol";


contract Pay is Initializable, OwnableUpgradeable{

    IMerchant public immutable iMerchant;

    uint256 public rate = 100;

    uint256 public fixedRate = 1000000;

    mapping(address => uint256) public tradeFeeOf;

    mapping(address => mapping(address => uint256)) public merchantFunds;

    mapping(address => mapping(string => address)) public merchantOrders;


    event Order(string orderId, uint256 paidAmount,address paidToken,uint256 orderAmount,address settleToken,uint256 fee,address merchant, address payer, bool isFixedRate);

    event Withdraw(address merchant, address settleToken, uint256 settleAmount, address settleAccount);

    event WithdrawTradeFee(address _token, uint256 _fee);


    receive() payable external {}

    function initialize()public initializer{
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    constructor(address _iMerchant){
        iMerchant = IMerchant(_iMerchant);
    }

    function pay(
        string memory _orderId,
        uint256 _orderAmount,
        address _merchant,
        address _currency
    ) external returns(bool) {

        require(_orderAmount > 0);
        require(address(0) == merchantOrders[_merchant][_orderId], "Order existed");
        require(iMerchant.isMerchant(_merchant), "Invalid merchant");
        require(iMerchant.validatorCurrency(_merchant, _currency), "Invalid token");
        require(IERC20(_currency).balanceOf(msg.sender) >= _orderAmount, "Balance insufficient");

        TransferHelper.safeTransferFrom(_currency, msg.sender, address(this), _orderAmount);

        (uint256 fee, bool isFixedRate) = getFee(_merchant, _orderAmount);

        if (iMerchant.getAutoSettle(_merchant)) {

            _autoWithdraw(_merchant, _currency, _orderAmount - fee);

        } else {

            merchantFunds[_merchant][_currency] += (_orderAmount - fee);

        }

        tradeFeeOf[_currency] += fee;

        emit Order(_orderId, _orderAmount, _currency, _orderAmount, _currency, fee, _merchant, msg.sender, isFixedRate);

        merchantOrders[_merchant][_orderId] = msg.sender;

        return true;

    }

    function claimToken(
        address _token,
        uint256 _amount,
        address _to
    ) external {

        require(address(0) != _token, "Invalid currency");
        require(iMerchant.isMerchant(msg.sender), "Invalid merchant");

        address settleAccount = _to;

        if(address(0) == _to) {
            settleAccount = iMerchant.getSettleAccount(msg.sender);
            if(address(0) == settleAccount) {
                settleAccount = msg.sender;
            }
        }

        _claim(msg.sender, _token, _amount, settleAccount);

    }

    function claimAllToken(address _to) external {

        require(iMerchant.isMerchant(msg.sender), "Invalid merchant");
        address[] memory merchantTokens = iMerchant.getMerchantTokens(msg.sender);

        for(uint i=0;i< merchantTokens.length; i++) {

            address token = merchantTokens[i];
            if (address(0) == token || merchantFunds[msg.sender][token] <= 0) {
                break;
            }

            _claim(msg.sender, token, merchantFunds[msg.sender][token], _to);

        }

    }

    function withdrawTradeFee(address _token) external onlyOwner {
        uint256 amount = tradeFeeOf[_token];
        TransferHelper.safeTransfer(_token, msg.sender, amount);
        tradeFeeOf[_token] = 0;
        emit WithdrawTradeFee(_token, amount);
    }

    function _autoWithdraw(
        address _merchant,
        address _settleToken,
        uint256 _settleAmount
    ) internal {

        address settleAccount = iMerchant.getSettleAccount(_merchant);

        if(address(0) == settleAccount) {
            settleAccount = _merchant;
        }

        TransferHelper.safeTransfer(_settleToken, settleAccount, _settleAmount);

        emit Withdraw(_merchant, _settleToken, _settleAmount, settleAccount);

    }

    function getFee(address _merchant, uint256 _orderAmount) internal view returns (uint256 fee,bool isFixedRate) {

        isFixedRate = iMerchant.getFixedRate(_merchant);
        if(isFixedRate) {
            fee = fixedRate;
        } else {
            fee = SafeMath.div((SafeMath.mul(_orderAmount ,rate)), 10000);
        }
        return (fee, isFixedRate);

    }

    function _claim(
        address _merchant,
        address _currency,
        uint256 _amount,
        address _settleAccount
    ) private {

        require(merchantFunds[_merchant][_currency] >= _amount);

        TransferHelper.safeTransfer(_currency, _settleAccount, _amount);

        merchantFunds[_merchant][_currency] -= _amount;

        emit Withdraw(_merchant, _currency, _amount, _settleAccount);

    }

    function setRate(uint256 _newRate) external onlyOwner {
        rate = _newRate;
    }

    function setFixedRate(uint256 _newFixedRate) external onlyOwner {
        fixedRate = _newFixedRate;
    }

}
