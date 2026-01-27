// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract AeroGaugeMock {
    AeroPoolMock public pool;

    constructor(address token0_, address token1_) {
        pool = new AeroPoolMock(token0_, token1_);
    }

    function stakingToken() external view returns (address) {
        return address(pool);
    }
}

contract AeroPoolMock {
    address public token0;
    address public token1;

    // Legacy fields (kept for backward compatibility)
    uint256 internal _reserve0Cumulative;
    uint256 internal _reserve1Cumulative;
    uint256 internal _blockTimestampLast;

    // New fields for TWAP and reserves
    uint256 internal _reserve0;
    uint256 internal _reserve1;
    uint256 internal _totalSupply;
    uint256 internal _quoteAmountOut;

    bool internal _shouldRevert;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    // Legacy setter (kept for backward compatibility)
    function setCumulativePrices(uint256 p0, uint256 p1, uint256 tsLast) external {
        _reserve0Cumulative = p0;
        _reserve1Cumulative = p1;
        _blockTimestampLast = tsLast;
    }

    // New setters
    function setReserves(uint256 r0, uint256 r1) external {
        _reserve0 = r0;
        _reserve1 = r1;
    }
    
    function setTotalSupply(uint256 supply) external {
        _totalSupply = supply;
    }
    
    function setQuoteAmountOut(uint256 amountOut) external {
        _quoteAmountOut = amountOut;
    }

    function setShouldRevert(bool v) external {
        _shouldRevert = v;
    }

    // New getters required by price feed
    function getReserves() external view returns (uint256, uint256, uint256) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        return (_reserve0, _reserve1, _blockTimestampLast);
    }
    
    function totalSupply() external view returns (uint256) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        return _totalSupply;
    }
    
    function quote(address, uint256, uint256) external view returns (uint256) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        return _quoteAmountOut;
    }

    // Legacy getter (kept for backward compatibility)
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative_, uint256 reserve1Cumulative_, uint256 blockTimestamp_)
    {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        return (_reserve0Cumulative, _reserve1Cumulative, _blockTimestampLast);
    }
}
