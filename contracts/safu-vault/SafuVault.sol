// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

/// @dev interface for interacting with the strategy
interface IStrategy {
    function want() external view returns (IERC20);
    function beforeDeposit() external;
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
}

/// @dev safu yield vault with automated strategy
contract SafuVault is ERC20, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // The strategy currently in use by the vault.
    IStrategy public strategy;

    constructor (
        IStrategy _strategy,
        string memory _name,
        string memory _symbol
    ) ERC20 (
        _name,
        _symbol
    ) {
        strategy = IStrategy(_strategy);
    }

    /// @dev token required as input for this strategy
    function want() public view returns (IERC20) {
        return IERC20(strategy.want());
    }

    /// @dev calculates amount of funds available to put to work in strategy
    function available() public view returns (uint256) {
        // * gets the balance of want in the contract.
        return want().balanceOf(address(this));
    }

    /// @dev calculates total underlying value of tokens held by system (vault+strategy)
    function balance() public view returns (uint256) {
        return available()+strategy.balanceOf();
        // * gets balance in the contract + balance in the strategy
    }

    /// @dev calls deposit() with all the sender's funds
    function depositAll() external {
        deposit(want().balanceOf(msg.sender));
    }
     
    /// @dev entrypoint of funds into the system
    /// @dev people deposit with this function into the vault
    // * main sequence of calls :
    // * vault.deposit calls strategy.beforeDeposit()
    // * strategy.beforeDeposit() gets the total want balance in the
    // * strategy contract. if that balance is > 0  then :
    // * 1 - call strategy.deposit() --> does nothing
    // * 2 - call strategy.sellHarvest() --> does nothing
    function deposit(uint256 _amount) public nonReentrant {
        // * this call does nothing in general.
        strategy.beforeDeposit();

        // * gets balance in strategy + balance in vault.
        uint256 _pool = balance();
        // * transfers the token from the user to the vault.
        want().safeTransferFrom(msg.sender, address(this), _amount);
        earn();
        uint256 _after = balance();
        _amount = _after - _pool; // Additional check for deflationary tokens

        uint256 shares;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / (_pool);
        }
        _mint(msg.sender, shares);
    }

    /// @dev sends funds to strategy to put them to work, by calling deposit() function
    function earn() public {
        // * gets the want balance available
        uint256 _bal = available();
        // * sends all the balance to the strategy
        want().safeTransfer(address(strategy), _bal);
        // * doesn't do anything 
        strategy.deposit();
    }

    /// @dev helper function to call withdraw() with all sender's funds
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /// @dev allows user to withdraw specified funds
    function withdraw(uint256 _shares) public {
        uint256 owed = (balance() * _shares) / (totalSupply());
        _burn(msg.sender, _shares); // will revert if _shares > what user has
    
        // ? this only checks the balance in this contract 
        // ? and does not check for the amount in strategy.
        // ? what if i transfer tokens to the vault.    

        // * first iteration :
        // * 1 - transfer 5000 token to the strategy
        // * 2 - deposit 5000 tokens in the vault
        // * stats : balance = 20000, totalSupply = 15000. Call withdraw with shares == 5000
        uint256 balance = want().balanceOf(address(this)); // check vault balance
  
        if (owed > balance) { // withdraw any extra required funds from strategy
        // * this will most likely be the case
        // * since deposit always moves the tokens to the strategy.
        // * gets the difference
            uint256 _withdraw = owed - balance;
            // * withdraw + balance = owed
            // * withdraw the difference froms strategy
            strategy.withdraw(_withdraw);
            // * gets the after amount.
            uint256 _after = want().balanceOf(address(this));
            // * after = withdraw + balance
            uint256 _diff = _after - balance;
            // * diff  = withdraw + balance - balance
            // * diff = withdraw.
            if (_diff < _withdraw) {
                // * this seems to just be rounding up
                // * and making sure that the below statment holds.
                owed = balance + _diff;
            }
        }
        // * transfers the tokens
        want().safeTransfer(msg.sender, owed);
    }

    /// @dev deposit funds into the system for other user
    function depositFor(
        address token, 
        uint256 _amount, 
        address user
    ) public {
        // ? there is no check to see if the `user`
        // ? is the vault or the strategy.
        // ? what if i deposited for the strategy ?
        // * does nothing.
        strategy.beforeDeposit();
        uint256 _pool = balance(); 
        // -- first call  0
        //    -- re-enter into deposit and add 5000
        IERC20(token).transferFrom(msg.sender, address(this), _amount);
   
        // * sends stuff to the vault.
        earn();
        uint256 _after = balance();
        // * gets the amount deposited.

        _amount = _after - _pool; // Additional check for deflationary tokens

        uint256 shares;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            // * mint shares.
            shares = (_amount * totalSupply()) / (_pool);
        }
        // * sends to user.
        // * note that shares are transferable.
        _mint(user, shares);
    }

}