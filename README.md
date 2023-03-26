#  StealthNFT

A small contract that allows to create a stealth address and mint NFTs to that address or any address.

## How to use

 - First, recipient needs to provide X and Y coordinates of recipient's public key.
 - To get their coordinates recipient can use `getPublicKey` in [Helper.js](https://github.com/nzmpi/StealthNFT/blob/main/scripts/Helper.js).
 - Only a signer can provide their public key.
 - Second, any user can call `getStealthAddress` with recipient's address and a secret string.
 - `getStealthAddress` should be called off-chain to keep everything private.
 - Finally, recipient can get their private key of a newly created stealth address using `getStealthPrivateKey` in Helper.js and published data from `getStealthAddress`. 

## Helper.js

Helper.js helps to get:

 - X and Y coordinates of user's public key using user's private key.
 - A stealth private key using user's private key and published data.

To call Helper.js use:

    yarn hardhat run scripts/Helper.js

## Run tests

    yarn hardhat test
    
## More info

For more info about stealth addresses read Vitalik Buterin's [post](https://vitalik.ca/general/2023/01/20/stealth.html).

