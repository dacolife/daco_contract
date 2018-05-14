pragma solidity ^0.4.23;

import "./common/Ownable.sol";
import "./common/SafeMath.sol";
import "./common/RefundCharityFabricInterface.sol";

/**
 * @title DACO congress contract
 * @dev http://daco.life
 */
contract DACOMain is Ownable {
    
    using SafeMath for uint256;
    
    /**
     * @dev Minimal quorum value
     */
    uint256 public minimumQuorum;

    /**
     * @dev Fabric for creating refund campaign
     */
    address public refundCharityFabric;

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
     * @dev Get campaign object by campaign hash
     */
    mapping(bytes32 => Campaign) campaigns;

    /**
     * @dev Campaigns hashes list
     */
    bytes32[] public campaignsHash;

    /**
     * @dev Count of campaigns in list
     */
    function numCampaigns() public view returns (uint256)
    { return campaignsHash.length; }



    // ---====== PROPOSALS ======---
    /**
     * @dev List of all proposals hashes
     */
    bytes32[] public proposalsHash;

    /**
     * @dev Count of proposals in list
     */
    function numProposals() public view returns (uint256)
    { return proposalsHash.length; }



    // ---====== FINISHED CAMPAIGNS ======---
    /**
     * @dev Campaigns list
     */
    bytes32[] public finishedCampaignsHash;

    /**
     * @dev Count of campaigns in list
     */
    function numFinishedCampaigns() public view returns (uint256)
    { return finishedCampaignsHash.length; }



    /**
     * @dev On proposal added
     * @param sender Sender address
     * @param hash Campaign hash
     * @param description Description
     * @param link Link to site
     */
    event ProposalAdded(
        address indexed sender,
        bytes32 indexed hash,
        string description,
        string link
    );

    /**
     * @dev On campaign added
     * @param sender Sender address
     * @param hash Campaign hash
     * @param description Description
     * @param link Link to site
     */
    event CampaignAdded(
        address indexed sender,
        bytes32 indexed hash,
        string description,
        string link
    );

    /**
     * @dev On proposal passed
     * @param sender Sender address
     * @param hash Campaign hash
     * @param owner Owner address
     * @param description Description
     * @param link Link to site
     */
    event ProposalPassed(
        address indexed sender,
        bytes32 indexed hash,
        address indexed owner,
        string description,
        string link
    );

    /**
     * @dev On vote by member accepted
     * @param sender Proposal sender
     * @param hash Campaign hash
     * @param supportsProposal Support proposal
     * @param comment Comment
     */
    event Voted(
        address indexed sender,
        bytes32 indexed hash,
        bool indexed supportsProposal,
        string comment
    );

    /**
     * @dev On finish campaign
     * @param sender Proposal sender
     * @param hash Campaign hash
     * @param raisedAmount Raised amount
     * @param report Report
     */
    event FinishCampaign(
        address indexed sender,
        bytes32 indexed hash,
        uint256 indexed raisedAmount,
        string report
    );

    /**
     * @dev create new donations contract
     * @param sender Sender
     * @param hash Campaign hash
     * @param donation address for donations
     */
    event CreateDonationContract(
        address indexed sender,
        bytes32 indexed hash,
        address indexed donation
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
     * @dev On changed membership
     * @param charityFabric Address fabric
     */
    event CharityFabricChanged(
        address indexed charityFabric
    );

    /**
     * @dev On voting rules changed
     * @param minimumQuorum New minimal count of votes
     * @param majorityMargin New majority margin value
     */
    event ChangeOfRules(
        uint256 indexed minimumQuorum,
        uint256 indexed majorityMargin
    );

    struct Campaign {
        bool isProposal;
        bool isCampaign;
        bool isFinishedCampaign;

        uint indexProposal;
        uint indexCampaign;
        uint indexFinishedCampaign;

        address owner;
        address[] wallets;
        uint256[] amounts;
        uint256 amount;
        string  description;
        string  link;

        address donationContract;

        address[] votesAddr;
        mapping(address => bool) voted;
        mapping(address => Vote) voteData;

        uint256 numberOfVotes;
        uint256 currentResult;

        uint256 proposalDate;
        bool proposalRejected;

        uint256 campaignDate;
        uint256 endDate;

        uint256 finishDate;
        uint256 raisedAmount;
        string  report;
    }

    struct Vote {
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
        bytes32[] campaignsHash;
        bytes32[] finishedCampaignsHash;
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
    function DACOMain(address _refundCharityFabric) public {
        setCharityFabric(_refundCharityFabric);
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
            members[_address].campaignsHash.length,
            members[_address].finishedCampaignsHash.length
        );
    }

    /**
     * @dev Get campaign common information
     * @param _hash Campaign hash key
     */
    function getCampaignCommonInfo(bytes32 _hash) public view returns (
        bool isProposal,
        bool isCampaign,
        bool isFinishedCampaign,
        address owner,
        uint256 endDate,
        uint256 amount,
        string description
    ) {
        return (
            campaigns[_hash].isProposal,
            campaigns[_hash].isCampaign,
            campaigns[_hash].isFinishedCampaign,
            campaigns[_hash].owner,
            campaigns[_hash].endDate,
            campaigns[_hash].amount,
            campaigns[_hash].description
        );
    }

    /**
     * @dev Get info for proposals
     * @param _hash Campaign hash
     */
    function getCampaignProposalInfo(bytes32 _hash) public view returns (
        bool isProposal,
        string link,
        uint256 countVotes,
        uint256 currentResult,
        uint256 proposalDate,
        bool proposalRejected
    ) {
        return (
            campaigns[_hash].isProposal,
            campaigns[_hash].link,
            campaigns[_hash].votesAddr.length,
            campaigns[_hash].currentResult,
            campaigns[_hash].proposalDate,
            campaigns[_hash].proposalRejected
        );
    }

    /**
     * @dev Get info for active campaigns
     * @param _hash Campaign hash
     */
    function getCampaignActiveInfo(bytes32 _hash) public view returns (
        bool isCampaign,
        string link,
        uint256 countVotes,
        uint256 currentResult,
        uint256 proposalDate,
        uint256 campaignDate,
        address donationContract
    ) {
        return (
            campaigns[_hash].isCampaign,
            campaigns[_hash].link,
            campaigns[_hash].votesAddr.length,
            campaigns[_hash].currentResult,
            campaigns[_hash].proposalDate,
            campaigns[_hash].campaignDate,
            campaigns[_hash].donationContract
        );
    }

    /**
     * @dev Get info for finished campaigns
     * @param _hash Campaign hash
     */
    function getCampaignFinishedInfo(bytes32 _hash) public view returns (
        string link,
        uint256 countVotes,
        uint256 campaignDate,
        uint256 finishDate,
        uint256 raisedAmount,
        string report,
        address donationContract
    ) {
        return (
            campaigns[_hash].link,
            campaigns[_hash].votesAddr.length,
            campaigns[_hash].campaignDate,
            campaigns[_hash].finishDate,
            campaigns[_hash].raisedAmount,
            campaigns[_hash].report,
            campaigns[_hash].donationContract
        );
    }

    /**
     * @dev Get info for campaigns indexes
     * @param _hash Campaign hash
     */
    function getCampaignIndexInfo(bytes32 _hash) public view returns (
        uint indexProposal,
        uint indexCampaign,
        uint indexFinishedCampaign
    ) {
        return (
            campaigns[_hash].indexProposal,
            campaigns[_hash].indexCampaign,
            campaigns[_hash].indexFinishedCampaign
        );
    }

    /**
     * @dev Get member who vote for campaign
     * @param _hash Campaign hash
     * @param _index Member index
     */
    function getCampaignVoteMemberAddress(bytes32 _hash, uint256 _index) public view returns (
        address
    ) {
        return (
            campaigns[_hash].votesAddr[_index]
        );
    }

    /**
     * @dev Get campaign
     * @param _hashCampaign Campaign hash
     * @param _addressMember Member address
     */
    function getCampaignVoteObject(bytes32 _hashCampaign, address _addressMember) public view returns (
        bool supportsProposal,
        address sender,
        string comment
    ) {
        return (
            campaigns[_hashCampaign].voteData[_addressMember].supportsProposal,
            campaigns[_hashCampaign].voteData[_addressMember].sender,
            campaigns[_hashCampaign].voteData[_addressMember].comment
        );
    }

    /**
     * @dev Get member campaign
     * @param _addressMember Member address
     * @param _index Campaign index
     */
    function getMemberCampaignAddress(address _addressMember, uint256 _index) public view returns (
        bytes32
    ) {
        return (
            members[_addressMember].campaignsHash[_index]
        );
    }

    /**
     * @dev Get member campaign
     * @param _addressMember Member address
     * @param _index Campaign index
     */
    function getMemberFinishedCampaignAddress(address _addressMember, uint256 _index) public view returns (
        bytes32
    ) {
        return (
            members[_addressMember].finishedCampaignsHash[_index]
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
     * @dev set fabric for creating new smart contracts
     * @param _newCharityFabric address of new fabric
     */
    function setCharityFabric(address _newCharityFabric) public onlyOwner {
        require(_newCharityFabric != 0x0);
        refundCharityFabric = _newCharityFabric;

        CharityFabricChanged(refundCharityFabric);
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
     * @param _wallets Beneficiary account addresses
     * @param _amounts Amount values in wei
     * @param _endDate End date
     * @param _description Description string
     * @param _link Link
     */
    function newProposal(
        address[] _wallets,
        uint256[] _amounts,
        uint256 _endDate,
        string  _description,
        string  _link
    )
    public
    returns (uint256 id)
    {
        require(_endDate > block.timestamp);

        require(_wallets.length <= 10);
        require(_wallets.length == _amounts.length);

        uint256 amount = 0;
        for (uint i = 0; i < _wallets.length; i++) {
            require(_wallets[i] != 0x0);
            require(_amounts[i] > 0);
            amount = amount.add(_amounts[i]);
        }

        bytes32 _hash = generateHash(_wallets);

        campaigns[_hash].indexProposal = proposalsHash.push(_hash) - 1;
        campaigns[_hash].isProposal = true;
        campaigns[_hash].isCampaign = false;
        campaigns[_hash].isFinishedCampaign = false;

        campaigns[_hash].owner = msg.sender;
        campaigns[_hash].wallets = _wallets;
        campaigns[_hash].amounts = _amounts;
        campaigns[_hash].amount = amount;
        campaigns[_hash].endDate = _endDate;
        campaigns[_hash].description = _description;
        campaigns[_hash].link = _link;
        campaigns[_hash].numberOfVotes = 0;
        campaigns[_hash].currentResult = 0;
        campaigns[_hash].proposalDate = now;
        campaigns[_hash].proposalRejected = false;

        ProposalAdded(msg.sender, _hash, _description, _link);
    }

    /**
     * @dev Create a new campaign
     * @param _wallets Beneficiary account address
     * @param _amounts Amount value in wei
     * @param _endDate End date
     * @param _description Description string
     * @param _link Link
     * @param _comment Comment
     */
    function newCampaign(
        address[] _wallets,
        uint256[] _amounts,
        uint256 _endDate,
        string  _description,
        string  _link,
        string  _comment
    )
    public
    onlyMembers
    returns (address)
    {
        require(_endDate > block.timestamp);

        require(_wallets.length <= 10);
        require(_wallets.length == _amounts.length);

        uint256 amount = 0;
        for (uint i = 0; i < _wallets.length; i++) {
            require(_wallets[i] != 0x0);
            require(_amounts[i] > 0);
            amount = amount.add(_amounts[i]);
        }

        bytes32 _hash = generateHash(_wallets);

        campaigns[_hash].indexCampaign = campaignsHash.push(_hash) - 1;
        campaigns[_hash].isProposal = false;
        campaigns[_hash].isCampaign = true;
        campaigns[_hash].isFinishedCampaign = false;

        campaigns[_hash].owner = msg.sender;
        campaigns[_hash].wallets = _wallets;
        campaigns[_hash].amounts = _amounts;
        campaigns[_hash].amount = amount;
        campaigns[_hash].endDate = _endDate;
        campaigns[_hash].description = _description;
        campaigns[_hash].link = _link;
        campaigns[_hash].numberOfVotes = 1;
        campaigns[_hash].currentResult = 1;
        campaigns[_hash].proposalDate = now;
        campaigns[_hash].campaignDate = now;
        campaigns[_hash].proposalRejected = false;
        campaigns[_hash].voted[msg.sender] = true;
        campaigns[_hash].votesAddr.push(msg.sender);

        members[msg.sender].campaignsHash.push(_hash);

        Vote memory v;
        v.supportsProposal = true;
        v.sender = msg.sender;
        v.comment = _comment;

        campaigns[_hash].voteData[msg.sender] = v;

        CampaignAdded(msg.sender, _hash, _description, _link);

        return createDonationsContract(_hash);
    }

    /**
     * @dev Proposal voting
     * @param _hash Campaign hash
     * @param _supportsProposal Is member support proposal
     * @param _comment Comment
     */
    function vote(
        bytes32 _hash,
        bool _supportsProposal,
        string _comment
    )
    public
    onlyMembers
    returns (bool)
    {
        require(campaigns[_hash].isProposal);
        require(!campaigns[_hash].isCampaign);
        require(!campaigns[_hash].isFinishedCampaign);

        require(!campaigns[_hash].voted[msg.sender]);
        require(!campaigns[_hash].proposalRejected);

        campaigns[_hash].voted[msg.sender] = true; // Set this voter as having voted
        campaigns[_hash].votesAddr.push(msg.sender);

        Vote memory v;
        v.supportsProposal = _supportsProposal;
        v.sender = msg.sender;
        v.comment = _comment;

        campaigns[_hash].voteData[msg.sender] = v;

        campaigns[_hash].numberOfVotes++; // Increase the number of votes
        if (_supportsProposal) { // If they support the proposal
            campaigns[_hash].currentResult++; // Increase score
        }

        members[msg.sender].campaignsHash.push(_hash);

        // Create a log of this event
        Voted(msg.sender, _hash,  _supportsProposal, _comment);

        if (campaigns[_hash].numberOfVotes >= minimumQuorum) {
            if (campaigns[_hash].currentResult >= majorityMargin) {
                // Proposal passed; remove from proposalsHash and create campaign
                uint rowToDelete = campaigns[_hash].indexProposal;
                address keyToMove   = proposalsHash[proposalsHash.length-1];
                proposalsHash[rowToDelete] = keyToMove;
                campaigns[keyToMove].indexProposal = rowToDelete;
                proposalsHash.length--;

                campaigns[_hash].indexProposal = 0;
                campaigns[_hash].indexCampaign = campaignsHash.push(_hash) - 1;
                campaigns[_hash].isProposal = false;
                campaigns[_hash].isCampaign = true;
                campaigns[_hash].isFinishedCampaign = false;

                campaigns[_hash].campaignDate = now;

                ProposalPassed(msg.sender, _hash, campaigns[_hash].owner, campaigns[_hash].description, campaigns[_hash].link);

                createDonationsContract(_hash);
            } else {
                // Proposal failed
                campaigns[_hash].proposalRejected = true;
            }
        }

        return true;
    }

    /**
     * @dev Finish a campaign
     * @param _hash Campaign hash
     * @param _raisedAmount Raised amount value in wei
     * @param _report Report
     */
    function finishCampaign(
        bytes32 _hash,
        uint256 _raisedAmount,
        string _report
    )
    public
    onlyMembers
    returns (bool)
    {
        require(!campaigns[_hash].isProposal);
        require(campaigns[_hash].isCampaign);
        require(!campaigns[_hash].isFinishedCampaign);

        require(campaigns[_hash].voted[msg.sender]);
        require(!campaigns[_hash].proposalRejected);

        // Campaign finished; remove from campaignsHash and create finished campaign
        uint rowToDelete = campaigns[_hash].indexCampaign;
        address keyToMove   = campaignsHash[campaignsHash.length-1];
        campaignsHash[rowToDelete] = keyToMove;
        campaigns[keyToMove].indexCampaign = rowToDelete;
        campaignsHash.length--;

        campaigns[_hash].indexProposal = 0;
        campaigns[_hash].indexCampaign = 0;
        campaigns[_hash].indexFinishedCampaign = finishedCampaignsHash.push(_hash) - 1;
        campaigns[_hash].isProposal = false;
        campaigns[_hash].isCampaign = false;
        campaigns[_hash].isFinishedCampaign = true;

        campaigns[_hash].finishDate        = now;
        campaigns[_hash].raisedAmount      = _raisedAmount;
        campaigns[_hash].report            = _report;

        members[msg.sender].finishedCampaignsHash.push(_hash);

        FinishCampaign(msg.sender, _hash, _raisedAmount, _report);
        
        return true;
    }

    /**
     * @dev Create contract for donations
     * @param _hash Campaign hash
     */
    function createDonationsContract(
        bytes32 _hash
    )
    internal
    returns (address)
    {
        require(!campaigns[_hash].isProposal);
        require(campaigns[_hash].isCampaign);
        require(!campaigns[_hash].isFinishedCampaign);
        require(campaigns[_hash].donationContract == 0x0);

        address newContract = RefundCharityFabricInterface(refundCharityFabric).create(
            campaigns[_hash].wallets,
            campaigns[_hash].amounts,
            campaigns[_hash].endDate
        );

        campaigns[_hash].donationContract = newContract;

        CreateDonationContract(msg.sender, _hash, newContract);

        return newContract;
    }

    function generateHash(
        address[] _wallets
    )
    internal
    returns (bytes32)
    {
        return keccak256(_wallets, block.coinbase, block.number, block.timestamp);
    }
}
