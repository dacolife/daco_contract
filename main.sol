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
     * @dev Get delegate identifier by account address
     */
    mapping(address => uint256) public memberId;

    /**
     * @dev Congress members list
     */
    Member[] public members;

    /**
     * @dev Count of members in archive
     */
    function numMembers() public view returns (uint256)
    { return members.length; }



    // ---====== PROPOSALS ======---
    /**
     * @dev List of all proposals
     */
    Proposal[] public proposals;

    /**
     * @dev Get proposal identifier by address
     */
    mapping(address => uint256) public proposalId;

    /**
     * @dev Count of proposals in list
     */
    function numProposals() public view returns (uint256)
    { return proposals.length; }



    // ---====== CAMPAIGNS ======---
    /**
     * @dev Get campaign identifier by account address
     */
    mapping(address => uint256) public campaignId;

    /**
     * @dev Campaigns list
     */
    Campaign[] public campaigns;

    /**
     * @dev Count of campaigns in list
     */
    function numCampaigns() public view returns (uint256)
    { return campaigns.length; }



    // ---====== FINISHED CAMPAIGNS ======---
    /**
     * @dev Get finished campaign identifier by account address
     */
    mapping(address => uint256) public finishedCampaignId;

    /**
     * @dev Campaigns list
     */
    FinishedCampaign[] public finishedCampaigns;

    /**
     * @dev Count of campaigns in list
     */
    function numFinishedCampaigns() public view returns (uint256)
    { return finishedCampaigns.length; }



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

    struct Proposal {
        address owner;
        address wallet;
        uint256 amount;
        string  description;
        string  link;
        Vote[] votes;
        mapping(address => bool) voted;
        uint256 numberOfVotes;
        uint256 currentResult;

        uint256 proposalDate;
        bool proposalRejected;
    }

    struct Campaign {
        address owner;
        address wallet;
        uint256 amount;
        string  description;
        string  link;
        Vote[] votes;
        mapping(address => bool) voted;
        uint256 numberOfVotes;
        uint256 currentResult;

        uint256 proposalDate;

        uint256 campaignDate;
    }

    struct FinishedCampaign {
        address owner;
        address wallet;
        uint256 amount;
        string  description;
        string  link;
        Vote[] votes;
        mapping(address => bool) voted;
        uint256 numberOfVotes;
        uint256 currentResult;

        uint256 proposalDate;

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
        string  name;
        string  link;
        uint256 memberSince;
        uint256 numCampaigns;
        uint256 numFinishedCampaigns;
        mapping(address => uint256) memberCampaignId;
        uint256[] campaignsIds;
        mapping(address => uint256) memberFinishedCampaignId;
        uint256[] finishedCampaignsIds;
    }

    /**
     * @dev Modifier that allows only shareholders to vote and create new proposals
     */
    modifier onlyMembers {
        require (memberId[msg.sender] != 0);
        _;
    }

    /**
     * @dev First time setup
     */
    function DACOMain() public {
        changeVotingRules(1, 1);
        addMember(0, '', '');
        newProposal(0, 0, '', '');
    }

    /**
     * @dev Add new congress member
     * @param _targetMember Member account address
     * @param _memberName Member full name
     * @param _memberLink Member site
     */
    function addMember(address _targetMember, string _memberName, string _memberLink) public onlyOwner {
        require(memberId[_targetMember] == 0);

        memberId[_targetMember] = members.length;
        Member storage m  = members[memberId[_targetMember]];

        m.member = _targetMember;
        m.name = _memberName;
        m.link = _memberLink;
        m.memberSince = now;
        m.numCampaigns = 0;
        m.numFinishedCampaigns = 0;

        MembershipChanged(_targetMember, true);
    }

    /**
     * @dev Remove congress member
     * @param _targetMember Member account address
     */
    function removeMember(address _targetMember) public onlyOwner {
        require(memberId[_targetMember] != 0);

        uint256 targetId = memberId[_targetMember];
        uint256 lastId   = members.length - 1;

        // Move last member to removed position
        Member memory moved    = members[lastId];
        members[targetId]      = moved;
        memberId[moved.member] = targetId;

        // Clean up
        memberId[_targetMember] = 0;
        delete members[lastId];
        --members.length;

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
        require(proposalId[_wallet] == 0);

        proposalId[_wallet] = proposals.length;
        Proposal storage p  = proposals[proposalId[_wallet]];

        p.owner = msg.sender;
        p.wallet = _wallet;
        p.amount = _amount;
        p.description = _description;
        p.link = _link;
        p.numberOfVotes = 0;
        p.currentResult = 0;
        p.proposalDate = now;
        p.proposalRejected = false;

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
        require(campaignId[_wallet] == 0);

        campaignId[_wallet] = campaigns.length;
        Campaign storage c  = campaigns[campaignId[_wallet]];

        c.owner             = msg.sender;
        c.wallet            = _wallet;
        c.amount            = _amount;
        c.description       = _description;
        c.link              = _link;
        c.numberOfVotes     = 1;
        c.currentResult     = 1;
        c.proposalDate      = now;
        c.campaignDate      = now;
        c.voted[msg.sender] = true;
        c.votes.push(Vote({
                wallet: _wallet,
                supportsProposal: true,
                sender: msg.sender,
                comment: _comment
            }));

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
        uint256 _proposalId = proposalId[_wallet];
        require(_proposalId != 0);  // If proposal for this wallet exists

        Proposal storage p = proposals[_proposalId];     // Get the proposal
        require(!p.voted[msg.sender]);  // If has already voted, cancel
        require(!p.proposalRejected);  // If has already voted, cancel

        p.voted[msg.sender] = true;                     // Set this voter as having voted
        p.numberOfVotes++;                              // Increase the number of votes
        if (_supportsProposal) {                         // If they support the proposal
            p.currentResult++;                          // Increase score
        }

        p.votes.push(Vote({
            wallet: _wallet,
            supportsProposal: _supportsProposal,
            sender: msg.sender,
            comment: _comment
        }));

        // Create a log of this event
        Voted(msg.sender, _wallet,  _supportsProposal, _comment);


        if (p.numberOfVotes >= minimumQuorum) {
            if (p.currentResult >= majorityMargin) {
                // Proposal passed; create campaign
                campaignId[_wallet] = campaigns.length;
                Campaign storage c  = campaigns[campaignId[_wallet]];

                c.owner             = p.owner;
                c.wallet            = p.wallet;
                c.amount            = p.amount;
                c.description       = p.description;
                c.link              = p.link;
                c.numberOfVotes     = p.numberOfVotes;
                c.currentResult     = p.currentResult;
                c.proposalDate      = p.proposalDate;
                c.campaignDate      = p.campaignDate;
                c.voted             = p.voted;
                c.votes             = p.votes;

                uint256 _lastId   = proposals.length - 1;

                // Move last item to removed position
                Proposal memory moved    = proposals[_lastId];
                proposals[_proposalId]     = moved;
                proposalId[moved.wallet]   = _proposalId;

                // Clean up
                proposalId[_wallet] = 0;
                delete proposals[_lastId];
                --proposals.length;

                ProposalPassed(msg.sender, c.owner, c.wallet, c.amount, c.description, c.link);
            } else {
                // Proposal failed
                p.proposalRejected = true;
            }
        }

        return p.numberOfVotes;
    }

    /**
     * @dev Create a new campaign
     * @param _wallet Beneficiary account address
     * @param _raisedAmount Raised amount value in wei
     * @param _report Report
     */
    function endCampaign(
        address _wallet,
        uint256 _raisedAmount,
        string _report
    )
    public
    onlyMembers
    returns (bool)
    {
        uint256 _campaignId = campaigns[_wallet];
        require(_campaignId != 0);  // If campaign for this wallet exists

        Campaign storage c = campaigns[_campaignId]; // Get the campaign

        finishedCampaignId[_wallet] = finishedCampaigns.length;
        FinishedCampaign storage fc  = finishedCampaigns[finishedCampaignId[_wallet]];

        fc.owner             = c.owner;
        fc.wallet            = c.wallet;
        fc.amount            = c.amount;
        fc.description       = c.description;
        fc.link              = c.link;
        fc.numberOfVotes     = c.numberOfVotes;
        fc.currentResult     = c.currentResult;
        fc.proposalDate      = c.proposalDate;
        fc.campaignDate      = c.campaignDate;
        fc.voted             = c.voted;
        fc.votes             = c.votes;
        fc.finishDate        = now;
        fc.raisedAmount      = _raisedAmount;
        fc.report            = _report;

        uint256 _lastId   = campaigns.length - 1;

        // Move last item to removed position
        Campaign memory moved    = campaigns[_lastId];
        campaigns[_campaignId]     = moved;
        proposalId[moved.wallet]   = _campaignId;

        // Clean up
        campaignId[_wallet] = 0;
        delete campaigns[_lastId];
        --campaigns.length;

        FinishCampaign(msg.sender, _wallet, _raisedAmount, _report);
        
        return true;
    }
}
