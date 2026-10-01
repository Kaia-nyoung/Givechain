// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleDonation {

    // 1. 역할 관련 상태 변수
    address public owner;
    address payable public beneficiary;

    // 2. 캠페인 상태 및 기부 데이터
    bool public campaignActive;
    uint256 public totalDonated;
    mapping(address => uint256) public donations;

    // 3. 재진입 공격 방지용 변수
    bool private locked;

    // 4. 이벤트
    event Donated(address indexed donor, uint256 amount);
    event CampaignStatusChanged(bool active);
    event Withdrawn(address indexed to, uint256 amount);

    event BeneficiaryChanged(
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    // 5. constructor — 배포할 때 한 번 실행
    constructor(address payable initialBeneficiary) {
        owner = msg.sender;

        require(
            initialBeneficiary != address(0),
            "Invalid beneficiary address"
        );

        beneficiary = initialBeneficiary;
        campaignActive = true;
    }

    // 6. 운영자 권한 확인
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner can call this function"
        );
        _;
    }

    // 7. 수혜자 권한 확인
    modifier onlyBeneficiary() {
        require(
            msg.sender == beneficiary,
            "Only beneficiary can call this function"
        );
        _;
    }

    // 8. 재진입 공격 방지
    modifier nonReentrant() {
        require(!locked, "Reentrant call");

        locked = true;
        _;
        locked = false;
    }

    // 9. ETH 기부
    function donate() external payable {
        require(
            campaignActive,
            "Campaign is not active"
        );

        require(
            msg.value > 0,
            "Donation must be greater than zero"
        );

        donations[msg.sender] += msg.value;
        totalDonated += msg.value;

        emit Donated(msg.sender, msg.value);
    }

    // 10. 캠페인 활성화 / 중단
    function setCampaignActive(bool active)
        external
        onlyOwner
    {
        campaignActive = active;

        emit CampaignStatusChanged(active);
    }

    // 11. 수혜자 주소 변경
    function changeBeneficiary(
        address payable newBeneficiary
    )
        external
        onlyOwner
    {
        require(
            newBeneficiary != address(0),
            "Invalid beneficiary address"
        );

        require(
            address(this).balance == 0,
            "Contract balance must be zero"
        );

        address oldBeneficiary = beneficiary;
        beneficiary = newBeneficiary;

        emit BeneficiaryChanged(
            oldBeneficiary,
            newBeneficiary
        );
    }

    // 12. 기부금 출금
    function withdraw()
        external
        onlyBeneficiary
        nonReentrant
    {
        uint256 balance = address(this).balance;

        require(
            balance > 0,
            "No balance to withdraw"
        );

        (bool success, ) = beneficiary.call{
            value: balance
        }("");

        require(
            success,
            "Withdrawal failed"
        );

        emit Withdrawn(beneficiary, balance);
    }

    // 13. 전체 누적 기부액 조회
    function getTotalDonatedInEther()
        external
        view
        returns (uint256)
    {
        return totalDonated / 1 ether;
    }

    // 14. 현재 계정의 누적 기부액 조회
    function getMyDonationInEther()
        external
        view
        returns (uint256)
    {
        return donations[msg.sender] / 1 ether;
    }

    // 15. 현재 컨트랙트 잔액 조회
    function getContractBalanceInEther()
        external
        view
        returns (uint256)
    {
        return address(this).balance / 1 ether;
    }
}