
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// GiveChain 호출 인터페이스
interface IGiveChain {
    function donate(uint256 campaignId) external payable;
    function refund(uint256 campaignId) external;
}

// 재진입 공격을 시도하는 테스트용 컨트랙트
contract RefundAttacker {

    IGiveChain public target;
    uint256 public targetCampaignId;

    uint256 public totalReceived;
    uint256 public reentryAttempts;
    bool public reentryBlocked;

    constructor(address targetAddress) {
        target = IGiveChain(targetAddress);
    }

    // 공격자 컨트랙트 주소로 기부
    function donateToCampaign(
        uint256 campaignId
    ) external payable {
        target.donate{value: msg.value}(campaignId);
    }

    // 환불 요청
    function attack(uint256 campaignId) external {
        targetCampaignId = campaignId;
        target.refund(campaignId);
    }

    // 환불받는 순간 다시 환불을 요청
    receive() external payable {
        totalReceived += msg.value;

        if (reentryAttempts == 0) {
            reentryAttempts++;

            try target.refund(targetCampaignId) {
                // 재진입이 성공하면 이곳으로 이동
            } catch {
                // 재진입 실패를 처리하여
                // 최초 정상 환불은 유지
                reentryBlocked = true;
            }
        }
    }
}
