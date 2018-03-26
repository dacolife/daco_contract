pragma solidity ^0.4.18;

import "./tokens/Ownable.sol";
import "./common/SafeMath.sol";

/**
 * @title Improved congress contract by Ethereum Foundation
 * @dev https://www.ethereum.org/dao#the-blockchain-congress
 */
contract DACOMain is Ownable {
    
    using SafeMath for uint256;
    
    /**
     * @dev Minimal quorum value
     */
    uint256 public minimumQuorum;

    /**
     * @dev Majority margin is used in voting procedure
     */
    uint256 public majorityMargin;



    // ---====== MEMBERS ======---
    /**
     * @dev Get delegate object by account address
     */
    mapping(address => Member) members;

    /**
     * @dev Congress members addresses list
     */
    address[] public membersAddr;

    /**
     * @dev Count of members in archive
     */
    function numMembers() public view returns (uint256)
    { return membersAddr.length; }



    // ---====== CAMPAIGNS ======---
    /**
     * @dev Get campaign object by account address
     */
    mapping(address => Campaign) campaigns;

    /**
     * @dev Campaigns addresses list
     */
    address[] public campaignsAddr;

    /**
     * @dev Count of campaigns in list
     */
    function numCampaigns() public view returns (uint256)
    { return campaignsAddr.length; }



    // ---====== PROPOSALS ======---
    /**
     * @dev List of all proposals addresses
     */
    address[] public proposalsAddr;

    /**
     * @dev Count of proposals in list
     */
    function numProposals() public view returns (uint256)
    { return proposalsAddr.length; }



    // ---====== FINISHED CAMPAIGNS ======---
    /**
     * @dev Campaigns list
     */
    address[] public finishedCampaignsAddr;

    /**
     * @dev Count of campaigns in list
     */
    function numFinishedCampaigns() public view returns (uint256)
    { return finishedCampaignsAddr.length; }



    /** msg.sender, wallet, amount, description, link
     * @dev On proposal added
     * @param sender Sender address
     * @param wallet Wallet address
     * @param amount Amount of wei
     * @param description Description
     * @param link Link to site
     */
    event ProposalAdded(
        address indexed sender,
        address indexed wallet,
        uint256 indexed amount,
        string description,
        string link
    );

    /**
     * @dev On campaign added
     * @param sender Sender address
     * @param wallet Wallet address
     * @param amount Amount of wei
     * @param description Description
     * @param link Link to site
     */
    event CampaignAdded(
        address indexed sender,
        address indexed wallet,
        uint256 indexed amount,
        string description,
        string link
    );

    /**
     * @dev On campaign added
     * @param sender Sender address
     * @param owner Owner address
     * @param wallet Wallet address
     * @param amount Amount of wei
     * @param description Description
     * @param link Link to site
     */
    event ProposalPassed(
        address indexed sender,
        address indexed owner,
        address indexed wallet,
        uint256 amount,
        string description,
        string link
    );

    /**
     * @dev On vote by member accepted
     * @param sender Proposal sender
     * @param wallet Proposal wallet
     * @param supportsProposal Support proposal
     * @param comment Comment
     */
    event Voted(
        address indexed sender,
        address indexed wallet,
        bool indexed supportsProposal,
        string comment
    );

    /**
     * @dev On vote by member accepted
     * @param sender Proposal sender
     * @param wallet Proposal wallet
     * @param supportsProposal Support proposal
     * @param comment Comment
     */
//    event Verified(
//        address indexed sender,
//        address indexed wallet,
//        bool indexed supportsProposal,
//        string comment
//    );

    /**
     * @dev On vote by member accepted
     * @param sender Proposal sender
     * @param wallet Proposal wallet
     * @param raisedAmount Raised amount
     * @param report Report
     */
    event FinishCampaign(
        address indexed sender,
        address indexed wallet,
        uint256 indexed raisedAmount,
        string report
    );

    /**
     * @dev On changed membership
     * @param member Account address
     * @param isMember Is account member now
     */
    event MembershipChanged(
        address indexed member,
        bool    indexed isMember
    );

    /**
     * @dev On voting rules changed
     * @param minimumQuorum New minimal count of votes
     * @param majorityMargin New majority margin value
     */
    event ChangeOfRules(
        uint256 indexed minimumQuorum,
        uint256  indexed majorityMargin
    );

    struct Campaign {
        bool isProposal;
        bool isCampaign;
        bool isFinishedCampaign;

        uint indexProposal;
        uint indexCampaign;
        uint indexFinishedCampaign;

        address owner;
        address wallet;
        uint256 amount;
        string  description;
        string  link;

        address[] votesAddr;
        mapping(address => bool) voted;
        mapping(address => Vote) voteData;

        //address[] verifiedAddr;
        //mapping(address => bool) verified;
        //mapping(address => Vote) verifiedData;

        uint256 numberOfVotes;
        uint256 currentResult;

        uint256 proposalDate;
        bool proposalRejected;

        uint256 campaignDate;

        uint256 finishDate;
        uint256 raisedAmount;
        string  report;
    }

    struct Vote {
        address wallet;
        bool supportsProposal;
        address sender;
        string comment;
    }

    struct Member {
        address member;
        bool active;
        bool isMember;
        string  name;
        string  link;
        uint256 memberSince;
        address[] campaignsAddr;
        address[] finishedCampaignsAddr;
        uint index;
    }

    /**
     * @dev Modifier that allows only shareholders to vote and create new proposals
     */
    modifier onlyMembers {
        require (members[msg.sender].isMember);
        require (members[msg.sender].active);
        _;
    }

    /**
     * @dev First time setup
     */
    function DACOMain() public {
        changeVotingRules(1, 1);
    }

    /**
     * @dev Get member
     * @param _address Member account address
     */
    function getMember(address _address) public view returns (
        bool active,
        bool isMember,
        string name,
        string link,
        uint256 memberSince,
        uint256 countCampaigns,
        uint256 countFinishedCampaigns
    ) {
        return (
            members[_address].active,
            members[_address].isMember,
            members[_address].name,
            members[_address].link,
            members[_address].memberSince,
            members[_address].campaignsAddr.length,
            members[_address].finishedCampaignsAddr.length
        );
    }

    /**
     * @dev Get campaign common information
     * @param _address Campaign wallet address
     */
    function getCampaignCommonInfo(address _address) public view returns (
        bool isProposal,
        bool isCampaign,
        bool isFinishedCampaign,
        address owner,
        address wallet,
        uint256 amount,
        string description
    ) {
        return (
            campaigns[_address].isProposal,
            campaigns[_address].isCampaign,
            campaigns[_address].isFinishedCampaign,
            campaigns[_address].owner,
            campaigns[_address].wallet,
            campaigns[_address].amount,
            campaigns[_address].description
        );
    }

    /**
     * @dev Get info for proposals
     * @param _address Campaign wallet address
     */
    function getCampaignProposalInfo(address _address) public view returns (
        bool isProposal,
        string link,
        uint256 countVotes,
        //uint256 countVerified,
        uint256 currentResult,
        uint256 proposalDate,
        bool proposalRejected
    ) {
        return (
            campaigns[_address].isProposal,
            campaigns[_address].link,
            campaigns[_address].votesAddr.length,
            //campaigns[_address].verifiedAddr.length,
            campaigns[_address].currentResult,
            campaigns[_address].proposalDate,
            campaigns[_address].proposalRejected
        );
    }

    /**
     * @dev Get info for active campaigns
     * @param _address Campaign wallet address
     */
    function getCampaignActiveInfo(address _address) public view returns (
        bool isCampaign,
        string link,
        uint256 countVotes,
        //uint256 countVerified,
        uint256 currentResult,
        uint256 proposalDate,
        uint256 campaignDate
    ) {
        return (
            campaigns[_address].isCampaign,
            campaigns[_address].link,
            campaigns[_address].votesAddr.length,
            //campaigns[_address].verifiedAddr.length,
            campaigns[_address].currentResult,
            campaigns[_address].proposalDate,
            campaigns[_address].campaignDate
        );
    }

    /**
     * @dev Get info for finished campaigns
     * @param _address Campaign wallet address
     */
    function getCampaignFinishedInfo(address _address) public view returns (
        string link,
        uint256 countVotes,
        //uint256 countVerified,
        uint256 campaignDate,
        uint256 finishDate,
        uint256 raisedAmount,
        string report
    ) {
        return (
            campaigns[_address].link,
            campaigns[_address].votesAddr.length,
            //campaigns[_address].verifiedAddr.length,
            campaigns[_address].campaignDate,
            campaigns[_address].finishDate,
            campaigns[_address].raisedAmount,
            campaigns[_address].report
        );
    }

    /**
     * @dev Get info for campaigns indexes
     * @param _address Campaign wallet address
     */
    function getCampaignIndexInfo(address _address) public view returns (
        uint indexProposal,
        uint indexCampaign,
        uint indexFinishedCampaign
    ) {
        return (
            campaigns[_address].indexProposal,
            campaigns[_address].indexCampaign,
            campaigns[_address].indexFinishedCampaign
        );
    }

    /**
     * @dev Get member who vote for campaign
     * @param _address Campaign wallet address
     * @param _index Member index
     */
    function getCampaignVoteMemberAddress(address _address, uint256 _index) public view returns (
        address
    ) {
        return (
            campaigns[_address].votesAddr[_index]
        );
    }

    /**
     * @dev Get member who verified campaign
     * @param _address Campaign wallet address
     * @param _index Member index
     */
//    function getCampaignVerifiedMemberAddress(address _address, uint256 _index) public view returns (
//        address
//    ) {
//        return (
//            campaigns[_address].verifiedAddr[_index]
//        );
//    }

    /**
     * @dev Get campaign
     * @param _addressCampaign Campaign wallet address
     * @param _addressMember Member address
     */
    function getCampaignVoteObject(address _addressCampaign, address _addressMember) public view returns (
        address wallet,
        bool supportsProposal,
        address sender,
        string comment
    ) {
        return (
            campaigns[_addressCampaign].voteData[_addressMember].wallet,
            campaigns[_addressCampaign].voteData[_addressMember].supportsProposal,
            campaigns[_addressCampaign].voteData[_addressMember].sender,
            campaigns[_addressCampaign].voteData[_addressMember].comment
        );
    }

    /**
     * @dev Get campaign
     * @param _addressCampaign Campaign wallet address
     * @param _addressMember Member address
     */
//    function getCampaignVerifyObject(address _addressCampaign, address _addressMember) public view returns (
//        address,
//        bool,
//        address,
//        string
//    ) {
//        return (
//            campaigns[_addressCampaign].verifiedData[_addressMember].wallet,
//            campaigns[_addressCampaign].verifiedData[_addressMember].supportsProposal,
//            campaigns[_addressCampaign].verifiedData[_addressMember].sender,
//            campaigns[_addressCampaign].verifiedData[_addressMember].comment
//        );
//    }

    /**
     * @dev Get member campaign
     * @param _memberAddress Campaign wallet address
     * @param _index Campaign index
     */
    function getMemberCampaignAddress(address _memberAddress, uint256 _index) public view returns (
        address
    ) {
        return (
            members[_memberAddress].campaignsAddr[_index]
        );
    }

    /**
     * @dev Get member campaign
     * @param _memberAddress Campaign wallet address
     * @param _index Campaign index
     */
    function getMemberFinishedCampaignAddress(address _memberAddress, uint256 _index) public view returns (
        address
    ) {
        return (
            members[_memberAddress].finishedCampaignsAddr[_index]
        );
    }

    /**
     * @dev Add new congress member
     * @param _targetMember Member account address
     * @param _memberName Member full name
     * @param _memberLink Member site
     */
    function addMember(address _targetMember, string _memberName, string _memberLink) public onlyOwner {
        require(_targetMember != 0x0);
        require(!members[_targetMember].isMember);

        members[_targetMember].index = membersAddr.push(_targetMember) - 1;
        members[_targetMember].active = true;
        members[_targetMember].isMember = true;

        members[_targetMember].member = _targetMember;
        members[_targetMember].name = _memberName;
        members[_targetMember].link = _memberLink;
        members[_targetMember].memberSince = now;

        MembershipChanged(_targetMember, true);
    }

    /**
     * @dev Remove congress member
     * @param _targetMember Member account address
     */
    function removeMember(address _targetMember) public onlyOwner {
        require(members[_targetMember].isMember);

        members[_targetMember].active = false;
        members[_targetMember].isMember = false;

        uint rowToDelete = members[_targetMember].index;
        address keyToMove   = membersAddr[membersAddr.length-1];
        membersAddr[rowToDelete] = keyToMove;
        members[keyToMove].index = rowToDelete;
        membersAddr.length--;

        MembershipChanged(_targetMember, false);
    }

    /**
     * @dev Activate member
     * @param _targetMember Member account address
     */
    function activateMember(address _targetMember) public onlyOwner {
        require(members[_targetMember].isMember);
        members[_targetMember].active = true;

        MembershipChanged(_targetMember, true);
    }

    /**
     * @dev Activate member
     * @param _targetMember Member account address
     */
    function deactivateMember(address _targetMember) public onlyOwner {
        require(members[_targetMember].isMember);
        members[_targetMember].active = false;

        MembershipChanged(_targetMember, false);
    }

    /**
     * @dev Change rules of voting
     * @param _minimumQuorumForProposals Minimal count of votes
     * @param _marginOfVotesForMajority Majority margin value
     */
    function changeVotingRules(
        uint256 _minimumQuorumForProposals,
        uint256 _marginOfVotesForMajority
    )
    public onlyOwner
    {
        minimumQuorum           = _minimumQuorumForProposals;
        majorityMargin          = _marginOfVotesForMajority;

        ChangeOfRules(minimumQuorum, majorityMargin);
    }

    /**
     * @dev Create a new proposal
     * @param _wallet Beneficiary account address
     * @param _amount Amount value in wei
     * @param _description Description string
     * @param _link Link
     */
    function newProposal(
        address _wallet,
        uint256 _amount,
        string  _description,
        string  _link
    )
    public
    returns (uint256 id)
    {
        require(_wallet != 0x0);
        require(!campaigns[_wallet].isProposal);
        require(!campaigns[_wallet].isCampaign);
        require(!campaigns[_wallet].isFinishedCampaign);

        campaigns[_wallet].indexProposal = proposalsAddr.push(_wallet) - 1;
        campaigns[_wallet].isProposal = true;
        campaigns[_wallet].isCampaign = false;
        campaigns[_wallet].isFinishedCampaign = false;

        campaigns[_wallet].owner = msg.sender;
        campaigns[_wallet].wallet = _wallet;
        campaigns[_wallet].amount = _amount;
        campaigns[_wallet].description = _description;
        campaigns[_wallet].link = _link;
        campaigns[_wallet].numberOfVotes = 0;
        campaigns[_wallet].currentResult = 0;
        campaigns[_wallet].proposalDate = now;
        campaigns[_wallet].proposalRejected = false;

        ProposalAdded(msg.sender, _wallet, _amount, _description, _link);
    }

    /**
     * @dev Create a new campaign
     * @param _wallet Beneficiary account address
     * @param _amount Amount value in wei
     * @param _description Description string
     * @param _link Link
     * @param _comment Comment
     */
    function newCampaign(
        address _wallet,
        uint256 _amount,
        string  _description,
        string  _link,
        string  _comment
    )
    public
    onlyMembers
    returns (uint256 id)
    {
        require(_wallet != 0x0);
        require(!campaigns[_wallet].isProposal);
        require(!campaigns[_wallet].isCampaign);
        require(!campaigns[_wallet].isFinishedCampaign);

        campaigns[_wallet].indexCampaign = campaignsAddr.push(_wallet) - 1;
        campaigns[_wallet].isProposal = false;
        campaigns[_wallet].isCampaign = true;
        campaigns[_wallet].isFinishedCampaign = false;

        campaigns[_wallet].owner = msg.sender;
        campaigns[_wallet].wallet = _wallet;
        campaigns[_wallet].amount = _amount;
        campaigns[_wallet].description = _description;
        campaigns[_wallet].link = _link;
        campaigns[_wallet].numberOfVotes = 1;
        campaigns[_wallet].currentResult = 1;
        campaigns[_wallet].proposalDate = now;
        campaigns[_wallet].campaignDate = now;
        campaigns[_wallet].proposalRejected = false;
        campaigns[_wallet].voted[msg.sender] = true;
        campaigns[_wallet].votesAddr.push(msg.sender);

        members[msg.sender].campaignsAddr.push(_wallet);

        Vote memory v;
        v.wallet = _wallet;
        v.supportsProposal = true;
        v.sender = msg.sender;
        v.comment = _comment;

        campaigns[_wallet].voteData[msg.sender] = v;

        CampaignAdded(msg.sender, _wallet, _amount, _description, _link);
    }

    /**
     * @dev Proposal voting
     * @param _wallet Beneficiary account address
     * @param _supportsProposal Is member support proposal
     * @param _comment Comment
     */
    function vote(
        address _wallet,
        bool _supportsProposal,
        string _comment
    )
    public
    onlyMembers
    returns (uint256 id)
    {
        require(_wallet != 0x0);
        require(campaigns[_wallet].isProposal);
        require(!campaigns[_wallet].isCampaign);
        require(!campaigns[_wallet].isFinishedCampaign);

        require(!campaigns[_wallet].voted[msg.sender]);
        require(!campaigns[_wallet].proposalRejected);

        campaigns[_wallet].voted[msg.sender] = true; // Set this voter as having voted
        campaigns[_wallet].votesAddr.push(msg.sender);


        Vote memory v;
        v.wallet = _wallet;
        v.supportsProposal = _supportsProposal;
        v.sender = msg.sender;
        v.comment = _comment;

        campaigns[_wallet].voteData[msg.sender] = v;

//        if (!campaigns[_wallet].verified[msg.sender]) {
//            campaigns[_wallet].verifiedData[msg.sender] = v;
//            campaigns[_wallet].verified[msg.sender] = true;
//            campaigns[_wallet].verifiedAddr.push(msg.sender);
//        }

        campaigns[_wallet].numberOfVotes++; // Increase the number of votes
        if (_supportsProposal) { // If they support the proposal
            campaigns[_wallet].currentResult++; // Increase score
        }

        members[msg.sender].campaignsAddr.push(_wallet);

        // Create a log of this event
        Voted(msg.sender, _wallet,  _supportsProposal, _comment);

        if (campaigns[_wallet].numberOfVotes >= minimumQuorum) {
            if (campaigns[_wallet].currentResult >= majorityMargin) {
                // Proposal passed; remove from proposalsAddr and create campaign
                uint rowToDelete = campaigns[_wallet].indexProposal;
                address keyToMove   = proposalsAddr[proposalsAddr.length-1];
                proposalsAddr[rowToDelete] = keyToMove;
                campaigns[keyToMove].indexProposal = rowToDelete;
                proposalsAddr.length--;

                campaigns[_wallet].indexProposal = 0;
                campaigns[_wallet].indexCampaign = campaignsAddr.push(_wallet) - 1;
                campaigns[_wallet].isProposal = false;
                campaigns[_wallet].isCampaign = true;
                campaigns[_wallet].isFinishedCampaign = false;

                campaigns[_wallet].campaignDate = now;

                ProposalPassed(msg.sender, campaigns[_wallet].owner, campaigns[_wallet].wallet, campaigns[_wallet].amount, campaigns[_wallet].description, campaigns[_wallet].link);
            } else {
                // Proposal failed
                campaigns[_wallet].proposalRejected = true;
            }
        }

        return campaigns[_wallet].numberOfVotes;
    }

    /**
     * @dev Finish a campaign
     * @param _wallet Beneficiary account address
     * @param _raisedAmount Raised amount value in wei
     * @param _report Report
     */
    function finishCampaign(
        address _wallet,
        uint256 _raisedAmount,
        string _report
    )
    public
    onlyMembers
    returns (bool)
    {
        require(_wallet != 0x0);
        require(!campaigns[_wallet].isProposal);
        require(campaigns[_wallet].isCampaign);
        require(!campaigns[_wallet].isFinishedCampaign);

        require(campaigns[_wallet].voted[msg.sender]);
        require(!campaigns[_wallet].proposalRejected);

        // Campaign finished; remove from campaignsAddr and create finished campaign
        uint rowToDelete = campaigns[_wallet].indexCampaign;
        address keyToMove   = campaignsAddr[campaignsAddr.length-1];
        campaignsAddr[rowToDelete] = keyToMove;
        campaigns[keyToMove].indexCampaign = rowToDelete;
        campaignsAddr.length--;

        campaigns[_wallet].indexProposal = 0;
        campaigns[_wallet].indexCampaign = 0;
        campaigns[_wallet].indexFinishedCampaign = finishedCampaignsAddr.push(_wallet) - 1;
        campaigns[_wallet].isProposal = false;
        campaigns[_wallet].isCampaign = false;
        campaigns[_wallet].isFinishedCampaign = true;

        campaigns[_wallet].finishDate        = now;
        campaigns[_wallet].raisedAmount      = _raisedAmount;
        campaigns[_wallet].report            = _report;

        members[msg.sender].finishedCampaignsAddr.push(_wallet);

        FinishCampaign(msg.sender, _wallet, _raisedAmount, _report);
        
        return true;
    }

    /**
     * @dev Verify a campaign
     * @param _wallet Beneficiary account address
     * @param _comment Comment
     */
//    function verifyCampaign(
//        address _wallet,
//        string _comment
//    )
//    public
//    onlyMembers
//    returns (bool)
//    {
//        require(_wallet != 0x0);
//        require(!campaigns[_wallet].isProposal);
//        require(campaigns[_wallet].isCampaign);
//        require(!campaigns[_wallet].isFinishedCampaign);
//
//        require(!campaigns[_wallet].verified[msg.sender]);
//
//        campaigns[_wallet].verified[msg.sender] = true; // Set this voter as having verify
//        campaigns[_wallet].verifiedAddr.push(msg.sender);
//
//        Vote memory v;
//        v.wallet = _wallet;
//        v.supportsProposal = true;
//        v.sender = msg.sender;
//        v.comment = _comment;
//
//        campaigns[_wallet].verifiedData[msg.sender] = v;
//
//        // Create a log of this event
//        Verified(msg.sender, _wallet,  true, _comment);
//
//        return true;
//    }
}
