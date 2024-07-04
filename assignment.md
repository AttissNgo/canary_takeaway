# Solidity Coding Challenge

Canary at its core works by allowing users to stake their tokens with different exit windows known as evergreen bonds, users can stake any whitelisted ERC-20 tokens and withdraw them after giving the specific notice period. 

Tasks:

1. Write a staker contract which allows the user to stake any ERC-20 token, 
    1. the staker should return a st-1w ERC-20 token back for 1 week notice period withdrawal
    2. the staker should return a st-4w ERC-20 token back for 4 week notice period withdrawal
2. The user should be able to requestWithdrawal and their st tokens be burned.
3. the user will stop earning interest once they request withdrawal (withdrawal amounts are fixed)
4. the user should be able to check their balance
5. admin should be able to deposit the yield into the contract weekly
6. user should be able to withdraw with the yield once their notice period has finished
7. the user should be able to earn 5% fixed interest as long as they hold the tokens
8. the user should be able to transfer and use the stake tokens like any other ERC-20 tokens

**Optionally:**

- User gets an NFT token once they request withdrawal which gets burned when the user claims the funds
- notice period is dynamic and can be changed by the admin
- the contract should be pausable

Important things

- Documentation should be provided
- Unit tests and fork tests should ensure the code works as intended
- Should use hardhat or forge for testing

Solidity Functions:

- deposit
- requestWithdraw
- claim
- balanceOf
- adminYieldDeposit
- pause
- unpause