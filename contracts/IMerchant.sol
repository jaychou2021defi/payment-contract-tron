// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMerchant {

    struct MerchantInfo {
        address account;
        address payable settleAccount;
        address settleCurrency;
        bool autoSettle;
        bool isFixedRate;
        address [] tokens;
    }

    function isMerchant(address _merchant) external view returns(bool);

    function addMerchant(address payable _settleAccount, address _settleCurrency, bool _autoSettle, bool _isFixedRate, address[] memory _tokens) external;

    function setMerchantToken(address[] memory _tokens) external;

    function getMerchantTokens(address _merchant) external view returns(address[] memory);

    function setSettleCurrency(address payable _currency) external;

    function getSettleCurrency(address _merchant) external view returns (address);

    function setSettleAccount(address payable _account) external;

    function getSettleAccount(address _account) external view returns(address);

    function setAutoSettle(bool _autoSettle) external;

    function getAutoSettle(address _merchant) external view returns (bool);

    function setFixedRate(bool _fixedRate) external;

    function getFixedRate(address _merchant) external view returns(bool);

    function validatorCurrency(address _merchant, address _currency) external view returns (bool);

}
