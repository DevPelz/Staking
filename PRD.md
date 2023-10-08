# Staking Contract with an annual Pr of 14%

## state variables

- struct that stores the stakers details
- struct that stores the compoundiing fee pool of the contract
- id for stakers
- mapping of id to staker details
- enum of auto-compounding (on/ off).

## function stake

- Users should be able to Deposit Eth
  - minimum of 0.01 eth precisely
  - the function should automatically convert eth to Weth before successfully depositing into the contract`(payable function)`.
  - mint a recipt/reward token to the depositor
  - the minted token should be calculated at a 1:10 proportion
    - Checks
      - check that the msg.sender is not address(0)
      - check that the msg.value is strictly greater than 0.01
    - ## Update state

## function auto compounding

- Users can opt for auto compounding
  - it would cost 1% fee of their weth monthly
    - so after every second i calculate how much should be deducted that after a month it should be equivalent to 1%
  - it can be trigggered by anyone externally
  - the person triggering this should be rewarded from the total auto compounding fee that the contract holds in a pool for paying gas
  - how it should work
  - after the full staking rewards has been earned reStake the rewards plus the initial capital and start another staking plan

## function withdraw

- Users can only withdraw after 7 days
  - checks
    - check that the msg.sender has rewards to claim
    - check that the withdrawal time is met
  - transfer the tokens plus rewards back to the user
