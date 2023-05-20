pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.8.3/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.8.3/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.8.3/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract PicKet is ERC721, ERC721URIStorage, VRFConsumerBaseV2, AutomationCompatibleInterface{

    uint public MINT_PRICE = 100000000000000;                       // Ticket price
    uint public MAX_SUPPLY = 10;                                    // Maximum number of ticket
    uint public ticketSupply = 0;                                   // Number of ticket suppleid

    mapping (address => uint256) private ticketOwners;              // map address to ticketId
    uint[] private ticketIdx = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];      // Array for random draw
    uint256[] private ticketDraws;                                  // user's random ticket idx


    uint public revealTime;                                         // Time when ticketing ends
    bool requestRandom = false;

    // VRF Variables
    VRFCoordinatorV2Interface public COORDINATOR;
    uint256 public s_randomWord;
    uint256 public s_requestId;
    uint32 public callbackGasLimit = 300000; // set higher as fulfillRandomWords is doing a LOT of heavy lifting.
    uint64 public s_subscriptionId;
    bytes32 keyhash =  0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;

    // Image srcs
    string baseUriIpfs = "https://ipfs.io/ipfs/bafkreigd4yw7zaamskpueuoydgouszgsvdmojntc22qr6ppv45gjj524ge?filename=BaseTicket";

    string[] ticketUrisIpfs = [
        "https://ipfs.io/ipfs/bafkreidaz6y33ly3o5lbuwlcewvoeudklbiaebwblpnb7qjm7mezxotra4?filename=VipTicket",
        "https://ipfs.io/ipfs/bafkreigffjwrz5vkpuctjgesmvo2ol45sqdn4w4j5s3wbe5h7vgndkdx4m?filename=EpicTicket",
        "https://ipfs.io/ipfs/bafkreie2lvrq6azrgri6eijabwoduca7irndhnsrxij3fps6fefg6achku?filename=NormalTicket"
    ];

    string[] photoUrisIpfs = [
        "https://ipfs.io/ipfs/bafkreiapgz5bbyzzgtupxiejlxzrg223to362hbtyxaeuvf2dcmf3m5w7m?filename=VipPhoto",
        "https://ipfs.io/ipfs/bafkreicb72kvkj5xjxrq42jyjms5ndvuknbobje7qik3pgpknvlklxto3e?filename=EpicPhoto",
        "https://ipfs.io/ipfs/bafkreidy6ghllpsmhvfmswyedg6hhe3idz3mj6eud4stizi635nos4xsdm?filename=NormalPhoto"
    ];

    event RequestFulfilled(uint256 randomWord);

    constructor(uint64 subId /* uint _revealTime */) VRFConsumerBaseV2(0x2eD832Ba664535e5886b75D64C46EB9a228C2610) ERC721("PicKet", "TPK"){
        // VRF variable
        COORDINATOR = VRFCoordinatorV2Interface(0x2eD832Ba664535e5886b75D64C46EB9a228C2610);
        s_subscriptionId = subId;
        // revealTime = _revealTime;
    }


    // Get random number from VRF automatically when ticketing time is finished
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */){
        upkeepNeeded = (revealTime != 0 && (block.timestamp > revealTime + 20) && !requestRandom);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if(revealTime != 0 && (block.timestamp > revealTime + 20) && !requestRandom){      
            requestRandom = true;
            requestRandomnessForTicketUris();
        }
    }

    function getTokenId(address ownerAddress) public view returns (uint id){
        require(ticketOwners[ownerAddress] != 0);
        id = ticketOwners[ownerAddress];
    }


    function mintTicket() public payable {
        // require(msg.value >= MINT_PRICE, "Insufficient funds to mint");
        require(ticketOwners[msg.sender] == 0, "Already bought one");
        require(MAX_SUPPLY > ticketSupply, "10 Tickets are already minted");
        
        // ticketId: 1 ~ 10
        uint256 ticketId = ticketSupply + 1;
        _safeMint(_msgSender(), ticketId);

        ticketOwners[msg.sender] = ticketId;
        _setTokenURI(ticketId, baseUriIpfs);

        ticketSupply++;

        // Only for testing purpose
        // revealTime should be indicating the end of ticketing time in real life
        if(ticketSupply == MAX_SUPPLY){
            revealTime = block.timestamp;
        }
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function requestRandomnessForTicketUris() public {
        require(s_subscriptionId != 0, "Subscription ID not set"); 

        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyhash,
            s_subscriptionId,
            3, 
            callbackGasLimit,
            1 
        );
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        s_randomWord = _randomWords[0];
        emit RequestFulfilled(_randomWords[0]);
    }

		
    function updateTokenUrisToTicket() public{
        require(s_randomWord != 0);
        require(ticketSupply == MAX_SUPPLY);
        uint256 random;
        uint256 mask = (1 << 24) - 1;
        
        for(uint i = 0; i < ticketSupply; i++){
            // ticketIdx
            // 0: VIP
            // 1 ~ 3: Epic
            // 4 ~ 9: Normal
            random =  ((s_randomWord >> (i * 24)) & mask) % ticketIdx.length;
            ticketDraws.push(ticketIdx[random]);
            
            
            if(ticketDraws[i] == 0){
                // set to VIP ticket
	            _setTokenURI(i+1, ticketUrisIpfs[0]); 
            }
            else if(ticketDraws[i] > 0 && ticketDraws[i] < 4){
                // set to Epic ticket
		          _setTokenURI(i+1, ticketUrisIpfs[1]);   
            }
            else{
                // set to Normal ticket
	            _setTokenURI(i+1, ticketUrisIpfs[2]);    
            }

            ticketIdx[random] = ticketIdx[ticketIdx.length - 1];
            ticketIdx.pop();
        }
    }
    
    function updateTokenUriToPhoto() public {
        require(ticketSupply == MAX_SUPPLY);
        for(uint i = 0; i < ticketSupply; i++){
            if(ticketDraws[i] == 0){
                // set to VIP photo
	            _setTokenURI(i+1, photoUrisIpfs[0]);    
            }
            else if(ticketDraws[i] > 0 && ticketDraws[i] < 4){
                // set to Epic photo
		          _setTokenURI(i+1, photoUrisIpfs[1]);   
            }
            else{
                // set to Normal photo
	            _setTokenURI(i+1, photoUrisIpfs[2]);    
            }
        }
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory){
        return super.tokenURI(tokenId);
    }
}