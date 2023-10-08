# Staking Contract with an annual Pr of 14%

## state variables

- struct that stores the stakers details including if auto compounding is enabled
- variable that holds the total compounding_pool balance.
- id for stakers
- mapping of id to staker details

## function stake

- Users should be able to Deposit Eth
  - minimum of 0.01 eth precisely
  - the function should automatically convert eth to Weth before successfully depositing into the contract`(payable function)`.
    - then transfer weth to the contract
    - keep track of the weth balance of the depositor as well so as to be able to track the pool
  - mint a recipt/reward token to the depositor
  - the minted token should be calculated at a 1:1 proportion
    - Checks
      - check that the msg.value is strictly greater than 0.01
    - ## Update state
      - automatically set autocompounding to be false
      - update the user recipt token balance

## function auto compounding

- Users can opt for auto compounding
  - it would cost 1% fee of their weth monthly
    - so after every second i calculate how much should be deducted so that after a month it should be equivalent to 1%
    - create pair with uniswapV2
    - swap the rewards token back to weth and add to the stake
  - it can be trigggered by anyone externally
  - the person triggering this should be rewarded from the total auto compounding fee that the contract holds in a pool for paying gas
  - how it should work
    - after the full staking rewards has been earned reStake the rewards plus the initial capital and start another staking plan

## function withdraw

- Users can only withdraw after 7 days
  - checks
    - check that the msg.sender has rewards to claim
    - check that the withdrawal time is metb
  - transfer the tokens plus rewards back to the user
