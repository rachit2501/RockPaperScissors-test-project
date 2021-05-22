// mock of dai token

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DAI is ERC20 {
    constructor() ERC20('DAI STABLECOIN', 'DAI') {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
