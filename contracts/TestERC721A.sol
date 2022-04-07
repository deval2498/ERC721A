// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {ERC721A} from "./ERC721A.sol";

contract TestERC721A is ERC721A, Ownable, Pausable {
    string public baseURI;

    address public proxyRegistryAddress;

    uint256 public MAX_SUPPLY = 5000;

    // mint allowance per address
    uint256 public MAX_PER_WHITELIST_ADDRESS = 3;
    uint256 public MAX_PER_AIRDROP_ADDRESS = 3;

    // public sale mint max per tx
    uint256 public MAX_PER_TX = 6;

    uint256 public mintPriceInWei = 0.5 ether;

    address public wallet1;
    address public wallet2;

    uint256 public feeToWalletPercent1;
    uint256 public feeToWalletPercent2;
    uint256 public totalFeeUnitPercent;

    bytes32 public whitelistMerkleRoot;
    bytes32 public airdropMerkleRoot;

    bool public isWhitelistMintOpen;
    bool public isAirdropMintOpen;
    bool public isPublicMintOpen;

    // track number of token minted
    mapping(address => uint256) public whitelistMinted;
    mapping(address => uint256) public airdropMinted;

    constructor(address _proxyRegistryAddress) ERC721A("Reforesta", "RFS") {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    //==================================
    //   MINT FUNC
    //==================================

    /**
     * @notice Mint for whitelist addresses
     * @dev Allow whitelist address to mint token not greater than on MAX_PER_WHITELIST_ADDRESS limit
     * @param _numberOfTokenToMint The number of token to mint
     * @param _proof The address proof
     */
    function whitelistMint(
        uint256 _numberOfTokenToMint,
        bytes32[] calldata _proof
    ) external payable {
        require(isWhitelistMintOpen, "Not yet open.");

        require(
            _verifySenderProof(_msgSender(), whitelistMerkleRoot, _proof),
            "invalid proof"
        );

        require(
            whitelistMinted[_msgSender()] + _numberOfTokenToMint <=
                MAX_PER_WHITELIST_ADDRESS,
            "Exceed max whitelist allowance"
        );
        require(
            _numberOfTokenToMint * mintPriceInWei == msg.value,
            "Invalid funds provided."
        );
        whitelistMinted[_msgSender()] += _numberOfTokenToMint;

        _safeMint(_msgSender(), _numberOfTokenToMint);
    }

    /**
     * @notice Mint the number of token not greater than MAX_PER_TX
     * @param count The number of token to mint
     */
    function publicMint(uint256 count) public payable {
        require(isPublicMintOpen, "Not yet open.");

        uint256 totalSupply = _totalMinted();
        require(totalSupply + count <= MAX_SUPPLY, "Exceeds max supply.");
        require(count <= MAX_PER_TX, "Exceeds max per transaction.");
        require(count * mintPriceInWei == msg.value, "Invalid funds provided.");

        _safeMint(_msgSender(), count);
    }

    /**
     * @notice Mint for airdop addresses
     * @dev Allow whitelist address to mint token not greater than on MAX_PER_WHITELIST_ADDRESS limit
     * @param _numberOfTokenToMint The number of token to mint
     * @param _proof The address proof
     */
    function airdropMint(
        uint256 _numberOfTokenToMint,
        bytes32[] calldata _proof
    ) external {
        require(isAirdropMintOpen, "Not yet open");

        uint256 totalSupply = _totalMinted();
        require(
            totalSupply + _numberOfTokenToMint <= MAX_SUPPLY,
            "Exceeds max supply."
        );

        require(
            _verifySenderProof(_msgSender(), airdropMerkleRoot, _proof),
            "invalid proof"
        );

        require(
            airdropMinted[_msgSender()] + _numberOfTokenToMint <=
                MAX_PER_AIRDROP_ADDRESS,
            "Exceed max whitelist allowance"
        );

        airdropMinted[_msgSender()] += _numberOfTokenToMint;

        _safeMint(_msgSender(), _numberOfTokenToMint);
    }

    //==================================
    //   Only Owner Access
    //==================================

    /**
     * @dev Set new mint price
     * @param _mintPriceInWei The new mint price
     */
    function setMintPrice(uint256 _mintPriceInWei) external onlyOwner {
        mintPriceInWei = _mintPriceInWei;
    }

    function setMaxSupply(uint256 maxSupply) external onlyOwner {
        MAX_SUPPLY = maxSupply;
    }

    /**
     * @dev Set limit that whitelist address can mint
     * @param _whitelistMintLimit The mint limit per whitelist address
     */
    function setMaxMintPerWhitelist(uint256 _whitelistMintLimit)
        external
        onlyOwner
    {
        MAX_PER_WHITELIST_ADDRESS = _whitelistMintLimit;
    }

    /**
     * @dev Set limit that airdop address can mint
     * @param _airdopMintLimit The mint limit per airdrop address
     */
    function setMaxMintPerAirdrop(uint256 _airdopMintLimit) external onlyOwner {
        MAX_PER_AIRDROP_ADDRESS = _airdopMintLimit;
    }

    /**
     * @dev Set limit mint per tx on public sale
     * @param _mintMaxPerTx The number of mint per tx
     */
    function setMaxPerTxMint(uint256 _mintMaxPerTx) external onlyOwner {
        MAX_PER_TX = _mintMaxPerTx;
    }

    function toggleWhitelistMintState() external onlyOwner {
        isWhitelistMintOpen = !isWhitelistMintOpen;
    }

    function toggleAirdopMintState() external onlyOwner {
        isAirdropMintOpen = !isAirdropMintOpen;
    }

    function togglePublicMintState() external onlyOwner {
        isPublicMintOpen = !isPublicMintOpen;
    }

    /**
     * @notice Allow owner to pause token transfer
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Allow owner to unpause token transfer
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Set wallet address where to send the sales fund
     * @param _wallet1 The reforesta wallet address
     * @param _wallet2 The reforesta wallet address
     */
    function setWallet(address _wallet1, address _wallet2) external onlyOwner {
        wallet1 = _wallet1;
        wallet2 = _wallet2;
    }

    /**
     * @notice Set OpenSea proxy
     * @param _proxyRegistryAddress The proxy address
     */
    function setProxyAddress(address _proxyRegistryAddress) external onlyOwner {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    /**
     * @dev Set whitelist address
     * @param _whitelistMerkleRoot The merkle root of whitelist addresses
     */
    function setWhitelistMerkleRoot(bytes32 _whitelistMerkleRoot)
        external
        onlyOwner
    {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    /**
     * @dev Set whitelist address
     * @param _airdropMerkleRoot The merkle root of airdrop addresses
     */
    function setAirdropMerkleRoot(bytes32 _airdropMerkleRoot)
        external
        onlyOwner
    {
        airdropMerkleRoot = _airdropMerkleRoot;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Withdraw eth balance
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance available");

        payable(wallet1).transfer(
            (balance * feeToWalletPercent1) / totalFeeUnitPercent
        );
        payable(wallet2).transfer(
            (balance * feeToWalletPercent2) / totalFeeUnitPercent
        );
    }

    /**
     * @dev Set fund distribution percent
     * @param _feeToWalletPercent1 The reforesta fund percent
     * @param _feeToWalletPercent2 The reforesta fund percent
     * @param _totalFeeUnitPercent The total fee unit percent
     */
    function setFee(
        uint256 _feeToWalletPercent1,
        uint256 _feeToWalletPercent2,
        uint256 _totalFeeUnitPercent
    ) external onlyOwner {
        feeToWalletPercent1 = _feeToWalletPercent1;
        feeToWalletPercent2 = _feeToWalletPercent2;
        totalFeeUnitPercent = _totalFeeUnitPercent;
    }

    //==================================
    //   Internal Function
    //==================================

    function _verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    function _verifySenderProof(
        address sender,
        bytes32 merkleRoot,
        bytes32[] calldata proof
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(sender));
        return _verify(proof, merkleRoot, leaf);
    }

    //==================================
    //   Override Function
    //==================================

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Token does not exist.");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
        require(!paused(), "paused token transfer");
    }
}

contract OwnableDelegateProxy {}

/**
 * Used to delegate ownership of a contract to another address, to save on unneeded transactions to approve contract use for users
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}
