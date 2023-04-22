# Zenon HTLC Test

A tool to automate HTLC testing with znn-cli


## Setup
Update the variables at the top of the script before running.  
You'll need to provision the accounts with the correct tokens first.  
Both keyStoreFiles need to be in the /path/to/znn/wallet/ directory and labeled as their default addresses.

**Dependency**
- argon2 is required to unlock the wallet. You may download a copy from [here](https://github.com/zenon-network/argon2_ffi/releases/).

**Examples**
- String ws = 'wss://node.zenon.fun:35998';
- String address1 = 'z1qr3uww8uqh75qnsuxqajegvwaesqynfglrare2';
- String address2 = 'z1qpusrlw26lly6cfwwjcrug5nnw4mkq5rr5h000';
- String passphrase1 = 'pass';
- String passphrase2 = 'pass';
- TokenStandard token1 = znnZts;
- TokenStandard token2 = TokenStandard.parse('zts1gs8cvx7z8dsglk8srtu0nm');
- double amount1 = 3.21;
- double amount2 = 1;
- int totalRuns = 1;

## Scenario
- **address1** will create an HTLC worth **amount1** **token1** that can be unlocked by **address2**
- **address2** will create an HTLC worth **amount2** **token2** that can be unlocked by **address1**
- **address1** will unlock **address1**'s HTLC and autoreceive the funds
- **address2** will unlock **address1**'s HTLC and autoreceive the funds
- the script will run **totalRuns** times

## Notes
- **address2** has the ability to parse the preimage from htlcAddress's account blocks but that logic is not included in this script.
