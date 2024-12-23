// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Owner {
   address owner;
   constructor() payable {
      owner = msg.sender;
   }
   modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }
   modifier costs(uint price) {
      if (msg.value >= price) {
        _;
      }
   }
}

contract GameContract is Owner{
    struct Match{
        address[] players;
        address winner;
        address designer;
        uint32 mapId;
        uint256 prizePool;
        bool finished;
    }

    struct Map{
        uint32 id;
        string name;
        address designer;
        uint8 size;
        uint256 totalEarned;
        uint256 earningPool;
    }

    // struct LeaderboardRecord{
    //     address player;
    //     uint32 wins;   
    //     uint32 loses;     
    // }

    mapping (uint64 => Match) private matches;
    mapping (uint32 => Map) private maps;

    // LeaderboardRecord[] private leaderboard;

    uint32 private prevMapId = 0;
    uint64 private prevMatchId = 0;
    uint256 private matchEntryFee = 0.0025 ether;
    
    uint256 private totalSpent; // Total am
    uint256 private totalEarned;
    uint256 private totalMapDesignersEarned;

    constructor() payable Owner(){

    }
    
    function registerMap(string memory name,address designer,uint8 size) public payable onlyOwner() returns (uint32){
        require(msg.value >= matchEntryFee, "Insufficient map registeration fee");
        prevMapId++;
        maps[prevMapId] = Map({
            id: prevMapId,
            name: name,
            designer: designer,
            size: size,
            totalEarned: 0,
            earningPool: 0
        });        

        return prevMapId;
    }

    //Only owner must call this function
    function createMatch(uint32 mapId) public onlyOwner() returns (uint64) {
        prevMatchId++;
        address[] memory players;
        matches[prevMatchId] = Match({
            players: players,
            winner : address(0),
            designer: address(0),
            mapId: mapId,
            prizePool: 0,
            finished: false
        });

        return prevMatchId;
    }

    function isInMatch(Match memory theMatch,address player) private pure returns (bool) {
        for(uint i=0;i<theMatch.players.length;i++){
            if(theMatch.players[i] == player)
                return true;
        } 
        return false;
    }

    function joinMatch(uint32 matchId) public payable{
        require(msg.value >= matchEntryFee, "Insufficient entry fee");
        Match storage joiningMatch = matches[matchId];
        require(!isInMatch(joiningMatch,msg.sender), "You're already in the match!"); 
        Map memory map = maps[joiningMatch.mapId]; 
        require(joiningMatch.players.length < map.size,"No room for new player");
        joiningMatch.players.push(msg.sender);        
        joiningMatch.prizePool += msg.value;
        totalSpent += msg.value;
    }

    function finishMatch(uint32 matchId, address winner) public onlyOwner(){
        //update leaderboard
        Match storage finishedMatch = matches[matchId];
        require(!finishedMatch.finished, "Match already finished"); // Ensure match is not already finished

        Map storage map = maps[finishedMatch.mapId];
    
        finishedMatch.winner = winner;

        uint256 prizePool = finishedMatch.prizePool;

        // Calculate shares
        uint256 mapDesignerShare = (prizePool * 5) / 100; // 5% to designer
        uint256 winnerShare = (prizePool * 75) / 100;  // 75% to owner
        uint256 ourShare = prizePool - mapDesignerShare - winnerShare; // 20% to winner

        // Update designer share
        map.totalEarned += mapDesignerShare;
        map.earningPool += mapDesignerShare;

        // Transfer funds to winner
        payable(finishedMatch.winner).transfer(winnerShare);

        totalEarned += ourShare;

    }

    function setMatchEntryFee(uint256 newFee) public onlyOwner {
        matchEntryFee = newFee;
    }

    function withdraw(uint256 amount, address payable targetAddress) public onlyOwner{
        payable(targetAddress).transfer(amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawForMapDesigner(uint32 mapId) public {
        Map storage map = maps[mapId];
        require(map.designer != address(0), "Map does not exist");
        require(msg.sender == map.designer, "Only the map designer can withdraw");
        payable(map.designer).transfer(map.earningPool);
        map.earningPool = 0;
    }
}
