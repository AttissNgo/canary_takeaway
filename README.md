# Minimal Staker

## Overview
The system comprises one Staker smart contract and any number of st-Token ERC20 contracts (two for each approved ERC20 token, for short withdraw notice and standard withdraw notice). Depositing, requesting withdrawals and claiming withdraws are handled through the Staker contract. The st-Tokens may be used like any other ERC20.
### Staking
Staking works by depositing approved ERC20 tokens in the Staker contract. st-Tokens will then be minted to the user at a 1:1 ratio.
### Withdrawing
A withdraw may be requested by burning st-Tokens, at which time a Claim token NFT will be minted by the Staker contract. After the given withdraw notice period, the NFT may be burned in exchange for the staked ERC20 tokens plus any accrued yield.
### Yield
5% per year fixed interest is earned on any balance of st-Tokens held. Yield amounts are updated whenever tokens are minted, transferred or burned. When a withdraw is requested, all accrued yield is realized in the issued Claim token and the user's yield is set to zero. Users may withdraw the accrued yield only by requesting a withdraw of 0 - in this case a Claim token will be minted which only represents the yield earned (the original balance will remain staked), and this claim is still subject to the withdraw notice period specified by the st-Token.

## Omissions, simplifications and changes
- Access control is represented only by a single `admin` address set in the constructor
- There is no mechanism for actually using the staked tokens. There is also no way for the admin to withdraw staked tokens. However, the liquidity reserved for honoring Claim tokens is tracked.
- `4. the user should be able to check their balance` - - - the `balanceOf` function given in the assignment clashes with the `balanceOf` function specified in ERC-721, so it has been changed to `getStake()` in the Staker contract.
- `5. admin should be able to deposit the yield into the contract weekly` is not implemented. In the scenario I imagine, the admin would keep the balance of all approver ERC20's 'topped up' by querying the issued Claim token NFTs and ensuring that the balance was available in the Staker contract by the time the notice period ended. If I have misunderstood this part of the assignment, please explain what I should have done here.