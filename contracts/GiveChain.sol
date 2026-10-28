
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GiveChain {

    enum Stage {
        NONE,
        OPEN,
        SUCCESS,
        FAILED
    }

    struct Campaign {
        address owner;
        string title;
        uint256 goal;
        uint256 raised;
        address payable beneficiary;
        Stage stage;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public donations;

    uint256 public nextCampaignId;
    bool private locked;

    // 이벤트 선언
    event CampaignCreated(
        uint256 indexed id,
        address indexed owner,
        string title
    );

    event Donated(
        uint256 indexed id,
        address indexed donor,
        uint256 amount
    );

    event CampaignFinalized(
        uint256 indexed id,
        Stage stage
    );

    event Withdrawn(
        uint256 indexed id,
        address indexed beneficiary,
        uint256 amount
    );

    event Refunded(
        uint256 indexed id,
        address indexed donor,
        uint256 amount
    );

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // 캠페인 생성
    function createCampaign(
        string calldata title,
        uint256 goal,
        address payable beneficiary
    ) external returns (uint256) {

        require(bytes(title).length > 0, "Title is empty");
        require(goal > 0, "Goal must be greater than zero");
        require(beneficiary != address(0), "Invalid beneficiary");

        uint256 campaignId = nextCampaignId;
        nextCampaignId++;

        campaigns[campaignId] = Campaign({
            owner: msg.sender,
            title: title,
            goal: goal,
            raised: 0,
            beneficiary: beneficiary,
            stage: Stage.OPEN
        });

        emit CampaignCreated(campaignId, msg.sender, title);

        return campaignId;
    }

    // 기부
    function donate(uint256 campaignId) external payable {
        require(campaignId < nextCampaignId, "Campaign does not exist");

        Campaign storage campaign = campaigns[campaignId];

        require(campaign.stage == Stage.OPEN, "Campaign is not open");
        require(msg.value > 0, "Donation must be greater than zero");

        campaign.raised += msg.value;
        donations[campaignId][msg.sender] += msg.value;

        emit Donated(campaignId, msg.sender, msg.value);
    }

    // 캠페인 마감
    function finalizeCampaign(uint256 campaignId) external {
        require(campaignId < nextCampaignId, "Campaign does not exist");

        Campaign storage campaign = campaigns[campaignId];

        require(msg.sender == campaign.owner, "Only campaign owner");
        require(campaign.stage == Stage.OPEN, "Campaign is not open");

        if (campaign.raised >= campaign.goal) {
            campaign.stage = Stage.SUCCESS;
        } else {
            campaign.stage = Stage.FAILED;
        }

        emit CampaignFinalized(campaignId, campaign.stage);
    }

    // 성공한 캠페인 출금
    function withdraw(uint256 campaignId) external nonReentrant {
        require(campaignId < nextCampaignId, "Campaign does not exist");

        Campaign storage campaign = campaigns[campaignId];

        require(campaign.stage == Stage.SUCCESS, "Campaign not successful");
        require(msg.sender == campaign.beneficiary, "Only beneficiary");

        uint256 amount = campaign.raised;
        require(amount > 0, "No funds to withdraw");

        campaign.raised = 0;

        (bool success, ) = campaign.beneficiary.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawn(campaignId, campaign.beneficiary, amount);
    }

    // 실패한 캠페인 환불
    function refund(uint256 campaignId) external nonReentrant {
        require(campaignId < nextCampaignId, "Campaign does not exist");

        Campaign storage campaign = campaigns[campaignId];

        require(campaign.stage == Stage.FAILED, "Campaign not failed");

        uint256 amount = donations[campaignId][msg.sender];
        require(amount > 0, "No donation to refund");

        donations[campaignId][msg.sender] = 0;
        campaign.raised -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");

        emit Refunded(campaignId, msg.sender, amount);
    }
}
