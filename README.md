# TruthChain Fact-Verification

A crowdsourced fact-checking platform for AI-generated claims with consensus-based truth scoring and verifier rewards.

## Features

- Claim submission with reward pool allocation
- Community-driven verification with scoring system
- Consensus-based truth score calculation
- Automated reward distribution for accurate verifiers
- Verifier reputation tracking

## Smart Contract Functions

### Public Functions

- `submit-claim` - Submit AI claim for verification with reward pool
- `verify-claim` - Submit verification score for pending claims
- `finalize-claim` - Close verification and calculate final truth score

### Read-Only Functions

- `get-claim` - Retrieve claim details and truth scores
- `get-verification` - Check individual verification submissions
- `get-verifier-stats` - View verifier reputation and history
- `get-claim-nonce` - Get current claim counter

## Usage

Submit claims for verification and participate in consensus-based fact-checking to earn rewards.