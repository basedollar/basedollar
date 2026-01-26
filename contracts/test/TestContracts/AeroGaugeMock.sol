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

    uint256 internal _reserve0Cumulative;
    uint256 internal _reserve1Cumulative;
    uint256 internal _blockTimestampLast;

    bool internal _shouldRevert;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setCumulativePrices(uint256 p0, uint256 p1, uint256 tsLast) external {
        _reserve0Cumulative = p0;
        _reserve1Cumulative = p1;
        _blockTimestampLast = tsLast;
    }

    function setShouldRevert(bool v) external {
        _shouldRevert = v;
    }

    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative_, uint256 reserve1Cumulative_, uint256 blockTimestamp_)
    {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        return (_reserve0Cumulative, _reserve1Cumulative, _blockTimestampLast);
    }
}