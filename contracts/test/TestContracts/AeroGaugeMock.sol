// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
    struct Observation {
        uint256 timestamp;
        uint256 reserve0Cumulative;
        uint256 reserve1Cumulative;
    }

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
    uint256 internal _quoteToken0ToToken1; // How much token1 for 1 token0
    uint256 internal _quoteToken1ToToken0; // How much token0 for 1 token1
    uint256 internal _twapReserve0;
    uint256 internal _twapReserve1;
    bool internal _useTwapReserves;
    Observation[] internal _customObservations;
    bool internal _useCustomObservations;

    bool internal _shouldRevert;
    bool internal _isStable;

    /// @dev Revert only on `quote` when quoting `token0` (first leg of TWAP)
    bool internal _revertQuoteToken0;
    /// @dev Revert only on `quote` when quoting `token1` (second leg of TWAP)
    bool internal _revertQuoteToken1;
    /// @dev Revert only `getReserves` (not `totalSupply`)
    bool internal _failGetReservesOnly;
    /// @dev Revert only `totalSupply` (not `getReserves`)
    bool internal _failTotalSupplyOnly;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setStable(bool v) external {
        _isStable = v;
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
    
    /// @notice Set quote amounts for both directions
    /// @param token0ToToken1 How much token1 returned when quoting 1 unit of token0
    /// @param token1ToToken0 How much token0 returned when quoting 1 unit of token1
    function setQuoteAmounts(uint256 token0ToToken1, uint256 token1ToToken0) external {
        _quoteToken0ToToken1 = token0ToToken1;
        _quoteToken1ToToken0 = token1ToToken0;

        uint256 token0Unit = 10 ** IERC20Metadata(token0).decimals();
        _twapReserve0 = token0Unit;
        _twapReserve1 = token0ToToken1;
        _useTwapReserves = true;
    }

    function setObservations(Observation[] calldata newObservations) external {
        delete _customObservations;
        for (uint256 i = 0; i < newObservations.length; i++) {
            _customObservations.push(newObservations[i]);
        }
        _useCustomObservations = true;
    }

    function setShouldRevert(bool v) external {
        _shouldRevert = v;
    }

    function setRevertQuoteToken0(bool v) external {
        _revertQuoteToken0 = v;
    }

    function setRevertQuoteToken1(bool v) external {
        _revertQuoteToken1 = v;
    }

    function setFailGetReservesOnly(bool v) external {
        _failGetReservesOnly = v;
    }

    function setFailTotalSupplyOnly(bool v) external {
        _failTotalSupplyOnly = v;
    }

    // New getters required by price feed
    function getReserves() external view returns (uint256, uint256, uint256) {
        if (_shouldRevert || _failGetReservesOnly) revert("AeroPoolMock: revert");
        return (_reserve0, _reserve1, _blockTimestampLast);
    }
    
    function totalSupply() external view returns (uint256) {
        if (_shouldRevert || _failTotalSupplyOnly) revert("AeroPoolMock: revert");
        return _totalSupply;
    }
    
    function quote(address tokenIn, uint256, uint256) external view returns (uint256) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        // Return appropriate quote based on input token direction
        if (tokenIn == token0) {
            if (_revertQuoteToken0) revert("AeroPoolMock: quote token0 revert");
            return _quoteToken0ToToken1;
        } else {
            if (_revertQuoteToken1) revert("AeroPoolMock: quote token1 revert");
            return _quoteToken1ToToken0;
        }
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

    function stable() external view returns (bool) {
        return _isStable;
    }

    function observationLength() external view returns (uint256) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        if (_useCustomObservations) return _customObservations.length;
        return 9;
    }

    function observations(uint256 index) external view returns (Observation memory) {
        if (_shouldRevert) revert("AeroPoolMock: revert");
        if (_useCustomObservations) return _customObservations[index];
        uint256 reserve0 = _useTwapReserves ? _twapReserve0 : _reserve0;
        uint256 reserve1 = _useTwapReserves ? _twapReserve1 : _reserve1;
        return Observation({
            timestamp: index + 1,
            reserve0Cumulative: reserve0 * (index + 1),
            reserve1Cumulative: reserve1 * (index + 1)
        });
    }
}
