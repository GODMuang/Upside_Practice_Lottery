// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Lottery{
    // 로또 구매자들을 저장하는 구조체
    struct LottoStruct{
        address buyer;
        uint lotteryNumber;
    }

    // 로또 당첨자들을 저장하는 구조체
    struct WinnerStruct{
        address winner;
        uint prize;
    }

    uint16 public winningNumber;
    uint prize;

    LottoStruct[] boughtLottery;
    WinnerStruct[] winners;

    uint sellPhaseEnd;
    uint claimPhaseEnd;
    

    uint randNonce = 1337;
    //
    constructor(){
        sellPhaseEnd = block.timestamp + 24 hours;
    }

    // testInsufficientFunds<number> 테스트를 만족하기 위한 modifier
    // 0.1 이더의 msg.value를 이용해 buy할 수 있도록 제한한다.
    modifier sufficientFund {
        require(msg.value == 0.1 ether, "insufficientFund");
        _;
    }

    // testNoDuplicate 테스트를 만족하기 위한 modifier 
    // 구매자 목록을 담고있는 boughtLottery 전체를 확인하여 
    // 중복 buy호출을 방지한다.
    modifier noDuplicate(uint lotteryNum){
        bool alreadyBought = false;
        for (uint i = 0; i < boughtLottery.length; i++) {
            if (boughtLottery[i].buyer == msg.sender) {
                alreadyBought = true;
                break;
            }
        }
        require(!alreadyBought, "You have already bought a ticket for this lottery");
        _;
    }

    // testSellPhaseFullLength, testNoBuyAfterPhaseEnd 를 만족하는 modifier
    // 24시간이라는 sellPhase동안만 구매할 수 있도록 시간을 제약한다.
    modifier buyPhaseModifier(){
        require(block.timestamp < sellPhaseEnd, "sell phase end.");
        _;
    }

    // testNoDrawDuringSellPhase 만족을 위한 modifier
    // sellPhase 이후에 draw를 호출할 수 있도록 한다.
    modifier drawModifier(){
        require(block.timestamp >= sellPhaseEnd, "no draw during sellphase");
        _;
    }

    // claimPhase를 관리하는 modifier
    modifier claimModifier(){
        require(block.timestamp < claimPhaseEnd, "no claim during sellphase");
        _;
    }

    // 랜덤수 생성기.
    // 블록 마이너가 블록해시를 조작할 수 있는 가능성때문에 안전하지않음.
    // 외부 오라클 이용을 권장.
    function WEAK_randomNumberGenerator() internal returns(uint16)
    {
        randNonce++;
        // 복권은 45번까지 허용
        // bytes32를 uint16으로 캐스팅하기 위해 uint256으로 확장.
        // nonce와 timestamp를 해싱하여 사용
        uint256 randomHash = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce)));
        return uint16(randomHash % 45);
    } 

    // 로또를 구매하는 함수.
    // sufficientFund modifier에 의해서 로또구매에 지불한 가격을 확인하고 (0.1이더)
    // noDuplicate modifier를 이용해 중복구매를 막으며
    // buyPhaseModifier를 이용해 구매가능기간을 확인한다.
    function buy(uint lotteryNum)public payable sufficientFund noDuplicate(lotteryNum) buyPhaseModifier(){
        boughtLottery.push();
        boughtLottery[boughtLottery.length-1].lotteryNumber = lotteryNum;
        boughtLottery[boughtLottery.length-1].buyer = msg.sender;


    }

    // 로또를 추첨하는 함수
    // drawModifier를 이용해 추첨가능기간을 확인한다.
    function draw() public drawModifier(){
        // 랜덤생성기를 이용해 추첨
        winningNumber = WEAK_randomNumberGenerator();
        // 추첨 후 claim에 10분을 부여.
        claimPhaseEnd = sellPhaseEnd + 10 minutes;
        // 구매자 목록에서 당첨자를 추린 후, winners 배열에 저장.
        for (uint i = boughtLottery.length; i > 0; i--) {
            if (boughtLottery[i-1].lotteryNumber == winningNumber ) {
                winners.push();
                winners[winners.length-1].winner = boughtLottery[i-1].buyer;
            }
            boughtLottery.pop();
        }
        
        // 만약 승자가 여러명이면 상금을 나눠줌
        if (winners.length != 0){
            prize = address(this).balance / winners.length;
            
        }

        // 각 회차 당첨자마다 상금을 저장
        for (uint i = 0; i < winners.length ; i++) {
            winners[i].prize = prize;
        }

        // 다음 sellPhase를 설정
        sellPhaseEnd = sellPhaseEnd + 24 hours;

    }

    // 당첨금을 지급하는 함수
    // 당첨자 목록 winner 배열에 msg.sender가 포함되어있으면
    // 보상을 지급하고 winners 목록에서 제외시킨 뒤 함수를 종료한다.
    function claim() public claimModifier(){
        for (uint i = winners.length; i > 0; i--) {
            if(winners[i-1].winner == msg.sender){
                (bool success, ) = msg.sender.call{value: prize}("");
                require(success, "claim transfer failed");
                // 마지막 element를 삭제할 element에 위치시킨 뒤
                // 중복된 마지막 element를 삭제.
                winners[i-1] = winners[winners.length - 1];
                winners.pop();
                break;
            }
        }

    }
}