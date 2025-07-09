# Tokenized Storm Water Management System

A comprehensive blockchain-based solution for managing urban storm water infrastructure using Clarity smart contracts on the Stacks blockchain.

## Overview

This system tokenizes storm water management operations, creating economic incentives for proper maintenance, monitoring, and environmental protection. The platform consists of five interconnected smart contracts that work together to create a sustainable and efficient storm water management ecosystem.

## System Components

### 1. Rainfall Monitoring Contract (`rainfall-monitoring.clar`)
- Tracks precipitation levels and weather patterns
- Records rainfall data from authorized weather stations
- Provides historical rainfall analytics
- Issues tokens for accurate data reporting

### 2. Drainage Optimization Contract (`drainage-optimization.clar`)
- Manages water flow through urban drainage infrastructure
- Tracks drainage system efficiency and capacity
- Rewards operators for system improvements
- Maintains optimization history and performance metrics

### 3. Flood Prediction Contract (`flood-prediction.clar`)
- Forecasts potential flooding risks using multiple data sources
- Calculates risk scores based on rainfall, drainage capacity, and historical data
- Issues early warning alerts for high-risk conditions
- Rewards accurate predictions and timely warnings

### 4. Infrastructure Maintenance Contract (`infrastructure-maintenance.clar`)
- Coordinates storm drain cleaning and repair operations
- Tracks maintenance schedules and completion status
- Manages contractor assignments and performance ratings
- Distributes rewards for completed maintenance tasks

### 5. Environmental Protection Contract (`environmental-protection.clar`)
- Monitors water quality parameters
- Prevents contaminated runoff from reaching waterways
- Tracks pollution levels and environmental compliance
- Incentivizes environmental protection measures

## Token Economics

Each contract issues its own fungible tokens as rewards for participation:
- **RAIN tokens**: Issued for accurate rainfall reporting
- **DRAIN tokens**: Rewarded for drainage system optimization
- **FLOOD tokens**: Given for accurate flood predictions
- **MAINT tokens**: Distributed for completed maintenance tasks
- **ENV tokens**: Awarded for environmental protection activities

## Key Features

- **Decentralized Monitoring**: Multiple authorized participants can contribute data
- **Economic Incentives**: Token rewards encourage active participation
- **Transparent Operations**: All activities recorded on-chain
- **Performance Tracking**: Comprehensive metrics and historical data
- **Quality Assurance**: Built-in validation and error checking

## Getting Started

### Prerequisites
- Clarinet CLI tool
- Node.js and npm for testing
- Stacks wallet for contract deployment

### Installation

1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`
4. Deploy contracts: `clarinet deploy`

### Usage

Each contract can be interacted with independently:

1. **Register as an operator** in the relevant contract
2. **Submit data** (rainfall, maintenance reports, etc.)
3. **Earn tokens** for accurate and timely contributions
4. **Monitor system status** through read-only functions

## Testing

The system includes comprehensive tests using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract scenarios
- Performance and stress testing
- Error handling validation

Run tests with: `npm test`

## Contract Architecture

### Data Structures
- **Maps**: Store persistent data (stations, drains, predictions, etc.)
- **Variables**: Track global state (rewards, totals, etc.)
- **Constants**: Define system parameters and error codes

### Security Features
- Authorization checks for sensitive operations
- Input validation and sanitization
- Error handling with descriptive codes
- Rate limiting for data submission

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions and support, please open an issue in the GitHub repository.
