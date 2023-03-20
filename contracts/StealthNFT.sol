// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./EllipticCurve.sol";

/**
 * @title StealthNFT
 * A contract that allows to create a stealth address and
 * mint NFTs to that address
 */
contract StealthNFT is ERC721 {
    EC ec;
    uint256 _totalSupply;
    
    event mintEvent(address indexed recipient, uint256 tokenID);

    // ec point
    struct Point {
        uint256 x;
        uint256 y;
    }

    mapping (address => Point) publicKeys;

    constructor() ERC721("StealthNFT", "SNFT") {
        ec = new EC();
    }

    function mint(address recipient) public returns (uint256 tokenID) {
        _mint(recipient, _totalSupply);
        emit mintEvent(recipient, _totalSupply);
        ++_totalSupply;
        unchecked{return _totalSupply-1;}
    }

    /**
     * Create a stealth address and mint to it
     * @notice not recommended, because it's called on-chain
     */
    function mintStealthily(
        address recipient, 
        string calldata secret
    ) public returns (
        address stealthAddress, 
        uint256 tokenID,
        bytes32 publishedDataX,
        bytes32 publishedDataY
    ) {
        (stealthAddress, publishedDataX, publishedDataY) = getStealthAddress(recipient, secret);
        tokenID = mint(stealthAddress);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function transfer(address recipient, uint256 tokenID) public {
        transferFrom(msg.sender, recipient, tokenID);
    }

    /**
     * @notice Only signer can provide their public key
     * @param publicKeyX - x coordinate of a public key
     * @param publicKeyY - y coordinate of a public key
     * @notice To get coordinates one can use ../scripts/Helper.js
     */
    function providePublicKey(bytes32 publicKeyX, bytes32 publicKeyY) external {
        bytes memory publicKey = abi.encodePacked(publicKeyX, publicKeyY);
        bool isSigner = (uint256(keccak256(publicKey)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF) == uint256(uint160(msg.sender));
        require(isSigner, "Not the signer!");
        publicKeys[msg.sender] = Point(uint256(publicKeyX), uint256(publicKeyY));
    }

    /**
     * @dev Should be called off-chain 
     * @dev more info: https://vitalik.ca/general/2023/01/20/stealth.html
     */
    function getStealthAddress(
        address recipientAddress, 
        string calldata secret
    ) public view returns (
        address stealthAddress, 
        bytes32 publishedDataX,
        bytes32 publishedDataY
    ) {
        Point memory publicKey = publicKeys[recipientAddress];
        // neither x nor y can be 0
        // checking one coordinate is enough
        require(publicKey.x != 0, "Public key not provided!");

        uint256 secretInt = uint256(keccak256(bytes(secret)));

        Point memory sharedSecret;
        (sharedSecret.x, sharedSecret.y) = ec.mul(secretInt, publicKey.x, publicKey.y);
        uint256 sharedSecretHashed = uint256(keccak256(abi.encodePacked(sharedSecret.x, sharedSecret.y)));
        Point memory sharedSecretHashedG;
        (sharedSecretHashedG.x, sharedSecretHashedG.y) = ec.mulG(sharedSecretHashed);

        Point memory stealthPublicKey;
        (stealthPublicKey.x, stealthPublicKey.y) = ec.add(publicKey.x, publicKey.y, sharedSecretHashedG.x, sharedSecretHashedG.y);
        bytes memory stealthPublicKeyHashed = abi.encodePacked(stealthPublicKey.x, stealthPublicKey.y);
        stealthAddress = address(uint160(uint256(keccak256(stealthPublicKeyHashed)) & 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));

        Point memory publishedData;
        (publishedData.x, publishedData.y) = ec.mulG(secretInt);
        publishedDataX = bytes32(publishedData.x);
        publishedDataY = bytes32(publishedData.y);
    }
}

contract EC is EllipticCurve {
    uint256 public constant GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 public constant GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint256 public constant AA = 0;
    uint256 public constant BB = 7;
    uint256 public constant PP = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /**
     * @dev Multiplies scalar _k and an ec point
     */
    function mul(uint256 _k, uint256 _x, uint256 _y) external pure returns (uint256 qx, uint256 qy) {
        (qx, qy) = ecMul(_k,_x,_y,AA,PP);
    }

    /**
     * @dev Multiplies scalar _k and a generator point G
     */
    function mulG(uint256 _k) external pure returns (uint256 qx, uint256 qy) {
        (qx, qy) = ecMul(_k,GX,GY,AA,PP);
    }

    function add(uint256 _x1, uint256 _y1, uint256 _x2, uint256 _y2) external pure returns (uint256 qx, uint256 qy) {
        (qx, qy) = ecAdd(_x1,_y1,_x2,_y2,AA,PP);
    }
}