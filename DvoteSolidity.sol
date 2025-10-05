// SPDX-License-Identifier: MIT
// Admin address:- 0x7af68A5683EA8F8B8EC192E8D038572975960228
//Candidate address:- 0x68F3391161Cd23da5590F1DC362F6d01c027dbE5, 0x43C01c6576D20A9043A5Cd69E19E34B1C0832014
//voter address:- 0x4A1a37eD91317593d5E6Cfce775A7fE2b54D28aD, 0x40059b174BE16f6B4A0B69DB9724a65Ef95F1cb6, 0xbA3B8E4F79B76d370831Abf50C7114F3C60De059
pragma solidity ^0.8.0;

contract DecisionVotingPlatform {
    address public admin;
    
    enum Phase { Setup, Voting, Reveal }
    Phase public currentPhase;
    
    struct VotingSession {
        string topic;
        string[] options;
        uint256[] votes;
        bool isActive;
        mapping(address => bool) hasVoted;
        mapping(address => bool) excludedVoters;
        mapping(address => uint256) voterChoices;
    }
    
    VotingSession public currentSession;
    
    // Events
    event SessionCreated(string topic, string[] options);
    event VoterExcluded(address voter);
    event VoterReinstated(address voter);
    event VoteCast(address voter, uint256 optionIndex);
    event VotingEnded();
    event ResultsRevealed(uint256[] votes);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyPhase(Phase _phase) {
        require(currentPhase == _phase, "Invalid phase for this action");
        _;
    }
    
    modifier onlyEligibleVoter() {
        require(!currentSession.excludedVoters[msg.sender], "Voter is excluded");
        require(msg.sender != admin, "Admin cannot vote");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        currentPhase = Phase.Setup;
        _initializeSession();
    }
    
    function _initializeSession() private {
        // Clear previous session data by creating new mapping storage
        currentSession.topic = "";
        delete currentSession.options;
        delete currentSession.votes;
        currentSession.isActive = false;
    }
    
    function createSession(string memory _topic, string[] memory _options) public onlyAdmin onlyPhase(Phase.Setup) {
        require(bytes(_topic).length > 0, "Topic cannot be empty");
        require(_options.length >= 2, "At least 2 options required");
        
        currentSession.topic = _topic;
        currentSession.options = _options;
        currentSession.votes = new uint256[](_options.length);
        currentSession.isActive = true;
        
        emit SessionCreated(_topic, _options);
    }
    
    function startVoting() public onlyAdmin onlyPhase(Phase.Setup) {
        require(bytes(currentSession.topic).length > 0, "Session not created");
        currentPhase = Phase.Voting;
    }
    
    function excludeVoter(address _voter) public onlyAdmin onlyPhase(Phase.Setup) {
        currentSession.excludedVoters[_voter] = true;
        emit VoterExcluded(_voter);
    }
    
    function reinstateVoter(address _voter) public onlyAdmin onlyPhase(Phase.Setup) {
        currentSession.excludedVoters[_voter] = false;
        emit VoterReinstated(_voter);
    }
    
    function castVote(uint256 _optionIndex) public onlyPhase(Phase.Voting) onlyEligibleVoter {
        require(!currentSession.hasVoted[msg.sender], "Already voted");
        require(_optionIndex < currentSession.options.length, "Invalid option index");
        
        currentSession.hasVoted[msg.sender] = true;
        currentSession.voterChoices[msg.sender] = _optionIndex;
        currentSession.votes[_optionIndex]++;
        
        emit VoteCast(msg.sender, _optionIndex);
    }
    
    function endVoting() public onlyAdmin onlyPhase(Phase.Voting) {
        currentPhase = Phase.Reveal;
        currentSession.isActive = false;
        emit VotingEnded();
    }
    
    function revealResults() public onlyAdmin onlyPhase(Phase.Reveal) {
        emit ResultsRevealed(currentSession.votes);
    }
    
    function resetSession() public onlyAdmin onlyPhase(Phase.Reveal) {
        _initializeSession();
        currentPhase = Phase.Setup;
    }
    
    // View functions
    function getTopic() public view returns (string memory) {
        return currentSession.topic;
    }
    
    function getOptions() public view returns (string[] memory) {
        return currentSession.options;
    }
    
    function getVotes() public view onlyPhase(Phase.Reveal) returns (uint256[] memory) {
        return currentSession.votes;
    }
    
    function getSessionStatus() public view returns (string memory) {
        if (currentPhase == Phase.Setup) return "Setup";
        if (currentPhase == Phase.Voting) return "Voting";
        return "Reveal";
    }
    
    function hasUserVoted(address _user) public view returns (bool) {
        return currentSession.hasVoted[_user];
    }
    
    function isVoterExcluded(address _user) public view returns (bool) {
        return currentSession.excludedVoters[_user];
    }
    
    function getUserVote(address _user) public view returns (uint256) {
        require(msg.sender == admin || msg.sender == _user, "Can only view own vote");
        return currentSession.voterChoices[_user];
    }
    
    function getWinningOptions() public view onlyPhase(Phase.Reveal) returns (uint256[] memory) {
        uint256 maxVotes = 0;
        uint256 winnerCount = 0;
        
        // Find max votes
        for (uint256 i = 0; i < currentSession.votes.length; i++) {
            if (currentSession.votes[i] > maxVotes) {
                maxVotes = currentSession.votes[i];
                winnerCount = 1;
            } else if (currentSession.votes[i] == maxVotes) {
                winnerCount++;
            }
        }
        
        // Get winning indices
        uint256[] memory winners = new uint256[](winnerCount);
        uint256 index = 0;
        for (uint256 i = 0; i < currentSession.votes.length; i++) {
            if (currentSession.votes[i] == maxVotes) {
                winners[index] = i;
                index++;
            }
        }
        
        return winners;
    }
}