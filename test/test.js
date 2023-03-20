const { ethers } = require('hardhat');
const { expect } = require("chai");
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

const EC = require('elliptic').ec;
const ec = new EC('secp256k1');

describe("StealthNFT", function() {
  const privateKey = '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
  const secret = 'test';
  let deployer, user, recipient;
  let contract;

  before(async function() {
    [deployer, user] = await ethers.getSigners();

    recipient = new ethers.Wallet(privateKey, ethers.provider);
    setBalance(recipient.address, ethers.utils.parseEther("1"));

    publicKey = {
      x: ethers.utils.hexDataSlice(recipient.publicKey, 1, 33),
      y: ethers.utils.hexDataSlice(recipient.publicKey, 33)
    }

    contract = await (await ethers.getContractFactory('StealthNFT', deployer)).deploy();
  });

  it("Should provide public key", async function() {
    let goodTx = contract
      .connect(recipient)
      .providePublicKey(publicKey.x, publicKey.y);

    await expect(goodTx).to.not.be.reverted;
  });

  it("Should not provide invalid public keys", async function() {
    let badTx = contract
      .connect(user)
      .providePublicKey(publicKey.x, publicKey.y);
      
    await expect(badTx).to.be.reverted;
  });

  it("Should get stealth address", async function() {
      const result = await contract.callStatic.getStealthAddress(recipient.address, secret);
      const [
        expectedStealthAddress, 
        expectedPublishedDataX, 
        expectedPublishedDataY
      ] = await getStealthAddress(privateKey, secret);

      expect(result.stealthAddress)
        .to.equal(expectedStealthAddress);
      expect(result.publishedDataX)
        .to.equal(expectedPublishedDataX);
      expect(result.publishedDataY)
        .to.equal(expectedPublishedDataY);
  });

  it("Should revert without a public key", async function() {
    await expect(contract.getStealthAddress(user.address, secret))
      .to.be.reverted;
  });

  it("Should mint", async function() {
    const tokenID = await contract.callStatic.mint(recipient.address);
    await contract.mint(recipient.address);

    expect(await contract.ownerOf(tokenID))
      .to.equal(recipient.address);
  });

  it("Should mint stealthily", async function() {
    const [
      stealthAddress,
      tokenID,,
      ] = await contract.callStatic.mintStealthily(recipient.address, secret);
    await contract.mintStealthily(recipient.address, secret);

    expect(await contract.ownerOf(tokenID))
      .to.equal(stealthAddress);
  });

  it("Should transfer", async function() {
    const tokenID = await contract.callStatic.mint(recipient.address);
    await contract.mint(recipient.address);

    await contract.connect(recipient).transfer(user.address, tokenID);

    expect(await contract.ownerOf(tokenID))
      .to.equal(user.address);
    });
  });

  async function getStealthAddress(privateKey, secret) {  
    // Remove "0x" prefix for elliptic library
    const privateKeyString = privateKey.slice(2);
    const publicKey = ec.g.mul(privateKeyString);

    // only works for strings <= 32 bytes
    let secretHex = ethers.utils.formatBytes32String(secret);
    // only works for 'test'
    secretHex = secretHex.slice(0,10);
    const secretHashed = ethers.utils.solidityKeccak256(
      ['bytes'],
      [ secretHex ]
    );

    const secretInt = secretHashed.slice(2);
    const sharedSecret = publicKey.mul(secretInt);
    const sharedSecretX = '0x' + sharedSecret.x.toString('hex');
    const sharedSecretY = '0x' + sharedSecret.y.toString('hex');
    const sharedSecretHashed = ethers.utils.solidityKeccak256(
      ['uint256', 'uint256'],
      [ sharedSecretX, sharedSecretY ]
    );  
    const sharedSecretHashedString = sharedSecretHashed.slice(2); 

    const stealthPublicKey = ec.g.mul(sharedSecretHashedString).add(publicKey);
    const stealthAddress = ethers.utils.computeAddress(
      "0x04"
      + stealthPublicKey.x.toString('hex')
      + stealthPublicKey.y.toString('hex')
    );

    const publishedData = ec.g.mul(secretInt);
    const publishedDataX = '0x' + publishedData.x.toString('hex');
    const publishedDataY = '0x' + publishedData.y.toString('hex');

    return [stealthAddress, publishedDataX, publishedDataY];
  }
