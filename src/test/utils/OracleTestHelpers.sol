// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "./../../Oracle.sol";
import "./../../libraries/Math.sol";
import "./../../helpers/TestToken.sol";
import "./Hevm.sol";
import "./../../interfaces/IERC20.sol";

contract OracleTestHelpers is DSTest, Hevm {

	struct OracleConfig {
		address tokenC;
		uint32 feeNumerator;
        uint32 feeDenominator;
        uint32 expireBufferBlocks;
        uint32 donBufferBlocks;
        uint32 resolutionBufferBlocks;
        uint16 donEscalationLimit;
        bool isActive;
	}

	struct MarketDetails {
		address tokenC;
        uint32 feeNumerator;
        uint32 feeDenominator;
	}

	struct StateDetails {
		uint32 expireAtBlock;
        uint32 donBufferEndsAtBlock;
        uint32 resolutionEndsAtBlock;
        uint32 donBufferBlocks; 
        uint32 resolutionBufferBlocks;
        uint16 donEscalationCount;
        uint16 donEscalationLimit;
        uint8 outcome;
        uint8 stage;
	}

	function deploySingleton() public returns (Oracle _singleton){
		_singleton = new Oracle();
	}

	function createAndFundMarket(address _oracle, address _creator, bytes32 _eventIdentifier, uint fundAmount) public {
		address _tokenC = Oracle(_oracle).collateralToken();
		IERC20(_tokenC).transfer(_oracle, fundAmount);
		Oracle(_oracle).createAndFundMarket(_creator, _eventIdentifier);
	}

	function buy(address to, address _oracle, bytes32 _marketIdentifier, uint a0, uint a1) public returns(uint a) {
        address _tokenC = getTokenC(_oracle, _marketIdentifier);
		(uint r0, uint r1) = Oracle(_oracle).outcomeReserves(_marketIdentifier);
		a = Math.getAmountCToBuyTokens(a0, a1, r0, r1);
		IERC20(_tokenC).transfer(_oracle, a);
		Oracle(_oracle).buy(a0, a1, to, _marketIdentifier);
	}

	function sell(address to, address _oracle, bytes32 _marketIdentifier, uint a0, uint a1) public returns (uint a) {
		(uint r0, uint r1) = Oracle(_oracle).outcomeReserves(_marketIdentifier);
		a = Math.getAmountCBySellTokens(a0, a1, r0, r1);

		(uint t0, uint t1) = Oracle(_oracle).getOutcomeTokenIds(_marketIdentifier);
		giveApprovalERC1155(to, address(this), _oracle);
		Oracle(_oracle).safeTransferFrom(to, _oracle, t0, a0, '');
		Oracle(_oracle).safeTransferFrom(to, _oracle, t1, a1, '');

		Oracle(_oracle).sell(a, to, _marketIdentifier);
	}

	function stakeOutcome(address _oracle, bytes32 _marketIdentifier, uint _for, uint amount, address to) public {
		address _tokenC = getTokenC(_oracle, _marketIdentifier);
		IERC20(_tokenC).transfer(_oracle, amount);
		Oracle(_oracle).stakeOutcome(uint8(_for), _marketIdentifier, to);
	}

	function giveApprovalERC1155(address _of, address to, address _oracle) public {
		if (to == _of) return;

		bytes memory data = abi.encodeWithSignature("setApprovalForAll(address,bool)", to, true);
		if (_of == address(this)){
			(bool success,) = _oracle.call(data);
			require(success);
		}
		else{
			(bool success,) = _of.call(abi.encodeWithSignature("send(address,bytes,bool)", _oracle, data, true));
			require(success);
		}
	}

    function getTokenC(address _oracle, bytes32 _marketIdentifier) public view returns (address _tokenC) {
        (_tokenC,,) = getMarketDetails(_oracle, _marketIdentifier);
    }

	function getTokenCResereves(address _oracle, bytes32 _marketIdentifier) public view returns (uint){
		address _tokenC = getTokenC(_oracle, _marketIdentifier);
		return Oracle(_oracle).cReserves(_tokenC);
	}

    function getMarketDetails(address _oracle, bytes32 _marketIdentifier) public view returns (address, uint32, uint32) {
        return Oracle(_oracle).marketDetails(_marketIdentifier);
    }

	function getMarketIdentifier(address _oracle, address _creator, bytes32 _eventIdentifier) public view returns (bytes32){
		return Oracle(_oracle).getMarketIdentifier(_creator, _eventIdentifier);
	}

	function getOutcomeReserves(address _oracle,  bytes32 _marketIdentifier) public view returns (uint r0, uint r1) {
		(r0, r1) = Oracle(_oracle).outcomeReserves(_marketIdentifier);
	}

	function getStakingReserves(address _oracle,  bytes32 _marketIdentifier) public view returns (uint r0, uint r1) {
		(r0, r1) = Oracle(_oracle).stakingReserves(_marketIdentifier);
	}

	function getOutcomeTokenIds(address _oracle,  bytes32 _marketIdentifier) public pure returns (uint t0, uint t1) {
		(t0, t1) = Oracle(_oracle).getOutcomeTokenIds(_marketIdentifier);
	}

	function getReserveTokenIds(address _oracle,  bytes32 _marketIdentifier) public pure returns (uint sTId0, uint sTId1){
		(sTId0, sTId1) = Oracle(_oracle).getReserveTokenIds(_marketIdentifier);
	}

	function getStaking(address _oracle,  bytes32 _marketIdentifier) public view returns (uint256 lastAmountStaked, address staker0, address staker1, uint8 lastOutcomeStaked) {
		(lastAmountStaked, staker0, staker1, lastOutcomeStaked) = Oracle(_oracle).staking(_marketIdentifier);
	}

	function getTokenCBalance(address _of, address _oracle,  bytes32 _marketIdentifier) public view returns (uint b) {
		address _tokenC = getTokenC(_oracle, _marketIdentifier);
		b = IERC20(_tokenC).balanceOf(_of);
	}

	function getOutcomeTokenBalance(address _of, address _oracle,  bytes32 _marketIdentifier) public view returns (uint bt0, uint bt1) {
		(uint t0, uint t1) = getOutcomeTokenIds(_oracle, _marketIdentifier);
		bt0 = Oracle(_oracle).balanceOf(_of, t0);
		bt1 = Oracle(_oracle).balanceOf(_of, t1);
	}

	function getStateDetail(address _oracle, bytes32 _marketIdentifier, uint index) public view returns(uint) {
		(
			uint32 expireAtBlock,
			uint32 donBufferEndsAtBlock,
			uint32 resolutionEndsAtBlock,
			uint32 donBufferBlocks,
			uint32 resolutionBufferBlocks,
			uint16 donEscalationCount,
			uint16 donEscalationLimit,
			uint8 outcome,
			uint8 stage
		) = Oracle(_oracle).stateDetails(_marketIdentifier);
		if (index == 0) return expireAtBlock;
		if (index == 1) return donBufferEndsAtBlock;
		if (index == 2) return resolutionEndsAtBlock;
		if (index == 3) return donBufferBlocks;
		if (index == 4) return resolutionBufferBlocks;
		if (index == 5) return donEscalationCount;
		if (index == 6) return donEscalationLimit;
		if (index == 7) return outcome;
		if (index == 8) return stage;
        return 0;
	}

	function getOracleFeeAmount(address _oracle, bytes32 _marketIdentifier, uint losingStake) public view returns (uint fee){
		(, uint feeNum, uint feeDenom) = getMarketDetails(_oracle, _marketIdentifier);
		fee = (feeNum*losingStake)/feeDenom;
	}

    function deloyAndPrepTokenC(address to) public returns (address _tokenC) {
        _tokenC = address(new TestToken());
        TestToken(_tokenC).mint(to, type(uint).max);
    }

	function checkReserves(address _oracle, bytes32 _marketIdentifier, uint er0, uint er1) public {
		(uint r0, uint r1) = getOutcomeReserves(_oracle, _marketIdentifier);
		assertEq(r0, er0);
        assertEq(r1, er1);
	} 

	function checkMarketDetails(address _oracle, bytes32 _marketIdentifier, MarketDetails memory _marketDetails) public {
		(address tokenC, uint32 feeNum, uint32 feeDenom) = getMarketDetails(_oracle, _marketIdentifier);
		assertEq(tokenC, _marketDetails.tokenC);
		assertEq(feeNum, _marketDetails.feeNumerator);
		assertEq(feeDenom, _marketDetails.feeDenominator);
	}

	function checkExpireAtBlock(address _oracle, bytes32 _marketIdentifier, uint _block) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 0), _block);
	}

	function checkDonBufferEndsAtBlock(address _oracle, bytes32 _marketIdentifier, uint _block) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 1), _block);
	}

	function checkResolutionEndsAtBlock(address _oracle, bytes32 _marketIdentifier, uint _block) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 2), _block);
	}

	function checkOutcome(address _oracle, bytes32 _marketIdentifier, uint outcome) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 7), outcome);
	}

	function checkStage(address _oracle, bytes32 _marketIdentifier, uint stage) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 8), stage);
	}

	function checkEscalationCount(address _oracle, bytes32 _marketIdentifier, uint count) public {
		assertEq(getStateDetail(_oracle, _marketIdentifier, 5), count);
	}

	function checkOutcomeTokenBalance(address _of, address _oracle, bytes32 _marketIdentifier, uint et0, uint et1) public {
		(uint t0, uint t1) = getOutcomeTokenIds(_oracle, _marketIdentifier);
		assertEq(Oracle(_oracle).balanceOf(_of, t0), et0);
		assertEq(Oracle(_oracle).balanceOf(_of, t1), et1);
	}

	function checkTokenCBalance(address _of, address _oracle, bytes32 _marketIdentifier, uint eb) public {
		assertEq(getTokenCBalance(_of, _oracle, _marketIdentifier), eb);
	}

	function checkStake(address _of, address _oracle, bytes32 _marketIdentifier, uint eb0, uint eb1) public {
		(uint sTId0, uint sTId1) = getReserveTokenIds(_oracle, _marketIdentifier);
		assertEq(Oracle(_oracle).balanceOf(_of, sTId0), eb0);
		assertEq(Oracle(_oracle).balanceOf(_of, sTId1), eb1);
	}

	function checkTokenCReserveMatchesBalance(address _oracle, bytes32 _marketIdentifier) public {
		address _tokenC = getTokenC(_oracle, _marketIdentifier);
		assertEq(Oracle(_oracle).cReserves(_tokenC), IERC20(_tokenC).balanceOf(_oracle));
	}

	function checkTokenCReserves(address _oracle, bytes32 _marketIdentifier, uint v) public {
		address _tokenC = getTokenC(_oracle, _marketIdentifier);
		assertEq(Oracle(_oracle).cReserves(_tokenC), v);
	}

	function checkRedeemWinning(address _of, address _oracle, bytes32 _marketIdentifier, uint a0, uint a1, uint eW) public {
		uint tokenCBalanceBefore = getTokenCBalance(_of, _oracle, _marketIdentifier);

		(uint t0, uint t1) = getOutcomeTokenIds(_oracle, _marketIdentifier);

		// transfer tokens
		giveApprovalERC1155(_of, address(this), _oracle);
		Oracle(_oracle).safeTransferFrom(_of, _oracle, t0, a0, '');
		Oracle(_oracle).safeTransferFrom(_of, _oracle, t1, a1, '');

		Oracle(_oracle).redeemWinning(_of, _marketIdentifier);

		uint tokenCBalanceAfter = getTokenCBalance(_of, _oracle, _marketIdentifier);

		assertEq(tokenCBalanceAfter-tokenCBalanceBefore, eW);
	}

	function checkRedeemStake(address _of, address _oracle, bytes32 _marketIdentifier, uint eW) public {
		uint tokenCBalanceBefore = getTokenCBalance(_of, _oracle, _marketIdentifier);

		Oracle(_oracle).redeemStake(_marketIdentifier, _of);

		uint tokenCBalanceAfter = getTokenCBalance(_of, _oracle, _marketIdentifier);
		assertEq(tokenCBalanceAfter-tokenCBalanceBefore, eW);
	}

	/* 
	Note - This function assumes that delegate is set to the contract's address
	 */
	function checkPassMarketResolution(address _oracle, bytes32 _marketIdentifier, uint outcome) public {
		uint tokenCBalanceBefore = getTokenCBalance(address(this), _oracle, _marketIdentifier);	
		(uint sRB0, uint sRB1) = getStakingReserves(_oracle, _marketIdentifier);
	
		Oracle(_oracle).setOutcome(uint8(outcome), _marketIdentifier);

		// estimate collection
		uint eFeeCollection;
		if (outcome != 2){
			if (outcome == 0){
				eFeeCollection = getOracleFeeAmount(_oracle, _marketIdentifier, sRB1);
			}else{
				eFeeCollection = getOracleFeeAmount(_oracle, _marketIdentifier, sRB0);
			}
		}

		// check fee collection
		uint tokenCBalanceAfter = getTokenCBalance(address(this), _oracle, _marketIdentifier);
		assertEq(tokenCBalanceAfter-tokenCBalanceBefore, eFeeCollection);

		// check staking reserves
		(uint sRA0, uint sRA1) = getStakingReserves(_oracle, _marketIdentifier);
		uint d0;
		uint d1;
		if (outcome != 2){
			if (outcome == 0){
				d0 = 0;
				d1 = eFeeCollection;
			}else {
				d0 = eFeeCollection;
				d1 = 0;
			}
		}

		assertEq(sRB0-sRA0, d0);
		assertEq(sRB1-sRA1, d1);
	}

	// function checkStateDetails(address _oracle, bytes32 _marketIdentifier, StateDetails memory _stateDetails) public {
	// 	(
	// 		uint32 expireAtBlock,
	// 		uint32 donBufferEndsAtBlock,
	// 		uint32 resolutionEndsAtBlock,
	// 		uint32 donBufferBlocks,
	// 		uint32 resolutionBufferBlocks,
	// 		uint16 donEscalationCount,
	// 		uint16 donEscalationLimit,
	// 		uint8 outcome,
	// 		uint8 stage
	// 	) = Oracle(_oracle).stateDetails(_marketIdentifier);
	// }

	/* 
// 	Market types
// 	 */
// 	enum MarketType {
// 		MarketWithNoStakesNoTrades,
// 		MarketWithNoStakesAndBiasedTrades,
// 		MarketWithNoStakesAndEqualTrades,
// 		MarketWithTradesAndStakesOnBothSides,
// 		MarketWithTradesAndStakesOnSingleSide
// 	}

// 	enum SimStage {
// 		InBuffer,
// 		BufferExpired,
// 		PostEscalationHit,

//     }

// 	function getMarketTypeMarketIdentifier(MarketType _type) public pure returns (bytes32 _identifier){
// 		_identifier = keccak256(abi.encode(uint(_type)));
// 	}

// 	function getMarketType(address _oracle, uint _fundAmount, Stages _atStage, MarketType _type) public returns (bytes32 _marketIdentifier) {
// 		if (_type == MarketType.MarketWithNoTrades){
// 			bytes32 _eventIdentifier = getMarketTypeMarketIdentifier(_type);
// 			_marketIdentifier = getMarketIdentifier(_oracle, address(this), _eventIdentifier);
//         	createAndFundMarket(_oracle, address(this), _eventIdentifier, _fundAmount);
// 		}


// 		if (_atStage == Stages.MarketBuffer){
// 			uint _block = getStateDetail(_oracle, _marketIdentifier, 0);
// 			roll(_block);
// 		}
// 		if (_atStage == Stages.Market)

// 	}
}


/* 
Tests I might be missing - 
1. When oracle resoles to outcome that is zero stakes

 */