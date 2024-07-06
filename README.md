Let's focus first on issuing the tokens. 2 tokens are specified - a 1W and a 4W st token.

They must be timelocked, which I think in this case simply means that they won't earn any interest on them until AFTER the timelock.
But I think they can still be transferred, burned, etc immediately.
So we just have to ensure that yield is not paid on the stTokens until after the timelock. 
But how?

- the yield is determined both by amount of time held and number of FUNGIBLE tokens
- the st token itself can have no metadata, so the time data must be stored in state somewhere else 
- the tokens are fungible, so simply recording a mapping of (user => (amount=>timelock)) won't work because the tokens could be transferred

So let's make a concession for simplicity and say that NOTHING can be done with the tokens during the staking period. 
This way, we can simply avoid minting them until after the staking period. 
After that, the user can burn to redeem, withdraw yield, transfer, etc.
So the only tokens that go into circulation are fully mature.

So let's start by writing the interfaces and thinking about storage and functionality.

- We need a separate st-ERC20 contract for every approved ERC20.
    - this means we'll probably need a factory 
    - the factory should deploy the new st-ERC20 when adding the new token to the whitelist 
    - !!! OOOORRRRR we could simply assume they're added in the constructor and leave the whitelisting/factory functionality out

- We need a way to keep track of timelocked deposits 

Right, so let's think yield through:
- the token itself does not produce yield. Rather it is the user's DEPOSIT. We just have to make sure they still have the tokens in their possession to claim the yield.
    - so the yield can be tracked in another data structure (their deposit), but we must not allow them to pull yield if they don't actually still have the tokens.
- so the assumption is that the st tokens represent liquid value within the protocol. The initial minter has an incentive to keep them, thus preserving liquidity, because if they transfer them, they will lose the yield that is tied to them. We have to be able to track this.

The key condition here is that tokens must remain staked in order to earn yield. This incentivizes holding the tokens and thus protects the liquidity of the staked value.


OPTIONS for handling timelock
1. st-Tokens minted on deposit | parallel data structure for storing amounts + time 
    - user can claim yield after timelock 
    - ? what happens if user transfers tokens? The new owner won't be able to claim the yield, but they will be able to withdraw 
    - # this doesn't really guarantee any liquidity since the user can withdraw at any time 
2. deposit simply creates a receipt for withdrawal later 


OH SHIT I GOT THIS WRONG
It's gotta give out the tokens right away. The 1w and 4w is the NOTICE period for withdrawing. They get the tokens immediately.

ok
New problem: how to track interest?
Alice stakes. She puts in some DAI and receives some st-DAI. 
Alice holds the st_DAI for one year, then requests withdrawal. The system burns the st-DAI, calculates yield, then issues a timestamped claim NFT which includes the total amount of DAI (original stake + yield) that can be withdrawn after the timelock.
- How does the system know how long the user has staked?
    - the must be some kind of receipt
- If Alice transfers her st-DAI to Bob, what happens when he requests a withdraw? Does the system grant him the same yield? How does it account for that?
- If Alice transfers her st_DAI to Bob, but then later he transfers it back, is Alice still eligible for the yield? Does the system know about transfers?


Possible solutions:
1. CLAIM NFT issued at deposit
    - tracks when x amount of t token was staked 
    - can be transferred along with st token to transfer yield, or user can hold and use with any st token 
    - ? what happens if a user wants to only claim a portion of the value represented in the NFT?
        - NFT amount will have to be updated each time a user withdraws 
    - ? what happens if a user wants to claim more st token than the NFT represents??

2. Store same info in a mapping to user's address
    - not transferrable, but encourages user to HOLD the st token, ensuring the stake more than transferring it around as value 
    mapping(address user => mapping(address token => stakeReceiptStruct))

Withdrawing --- in either scenario, when a user request withdrawal the system needs to:
- calculate the amount of yield they are owed on the entire withdrawal-- this could include different instances of staking, so different values on different amounts which ALL have to be updated
- burn the st tokens
- issue some sort of timelocked way to redeem for the actual underlying erc20 token 

Problem is the updating, especially with partial amounts (i.e. a withdraw request is LESS than the value of the receipt) - then the receipt has to be updated so the remainder can be used later. So we need multiple data structures. Let's think first about everything as an NFT
- A receipt NFT is issued at deposit. It contains an amount and a timestamp of when the deposit was made
- When requesting a withdraw, the receipt token is submitted with the st tokens
    - the st tokens are burned
    - the withdraw amount is subtracted from the receipt token (could be partial or could take multiple receipt tokens??)
        - if a receipt token's amount goes to zero, the token is burned 
    - a claim token is issued with the amount to withdraw (stake + yield earned) and the maturity date
- A claim token can be token can be redeemed AFTER its maturity date
    - the claim token will be burned
    - the underlying asset (with yield earned) will be sent to user 

Okay, now if it was a non-transferrable mapping:
- Receipt is issues at deposit, but is just stored in a mapping 
- withdraw procedure is pretty much the same - claim NFT is still issued 
- claim token is still redeemed in the same way 

Since st tokens have a set notice period, they cannot be redeemed at the same time, since ONE NFT has to represent the claim.

Fuck it, let's try it as NFTs..... hope I'm not being dumb here.\
NFTs are not only transferrable, but they're much easier to enumerate. 

What happens if someone tried to redeem WITHOUT a receipt???
- claim NFT is still issued, but then there is no yield.
    - this means there is yield left floating around in the system 
    - is this a problem? 
        - Alice buys 100 st tokens -> after 1 year she transfers to Bob but does not transfer Receipt
        - Alice buys 100 more st tokens (now she has two Receipts)
        - she sells her 100 new tokens with her old Receipt - gets the token value + 1 year worth of yield
        - now in the system there are still 100 tokens (bob), and a Receipt for a new Deposit --- nothing has been lost
        - How could this be exploited?
            - Alice mints 100 tokens, redeems them immediately but without the receipt - gets the value back with no yield
            - Now alice has a Receipt, so whenever she mints new tokens, it's as if she had them for a year, meaning that the value has accumulated for her, despite the tokens not being in the system. This can't work.
- The system MUST force the user to claim their yield when they request a withdraw
    - Only way to keep the yield accounted for properly (meaning it always represents tokens which are STILL IN THE SYSTEM) is to force the transfer of Receipts along with tokens


I think I get it. 
The stToken has to force an update whenever the token is transferred. Thus, value accrues over time. 
Work on that. I think it's the key.


So let's think through yield upon transfer.
Alice has 100 st tokens. She's held them for a year. She transfers them all to Bob -> the yield is updated to add 5% to her accrued yield. 
Now she has no tokens but is owed 5 st tokens in yield. How does she get those tokens??
We cannot simply give her the yield as tokens, because that yield is NOT staked, and therefore not eligible for earning yield.
So to get the yield with a zero balance, we would have to allow 0 withdraws in Staker.
I think...

Now we have to figure out how to take OUT the accruedYield

When user requests a withdrawal -> st Token executes a burn -> ALL yield is send to Staker to be used in claim NFT (even if it's only a partial burn of the assets) -> so to get your yield while keeping your assets staked, you call withdraw with 0.... does this create any problems?? 


