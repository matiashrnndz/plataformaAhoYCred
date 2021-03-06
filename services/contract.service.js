const path = require('path');
const fs = require('fs');
const solc = require('solc');
const { default: Web3 } = require('web3');

const configPath = path.resolve(process.cwd(), 'config.json');
const contractFileName = 'GeneralConfiguration.sol';
//const contractFileName = 'SavingAccount.sol';
const contractName = contractFileName.replace('.sol','');
const contractPath = path.resolve(process.cwd(), 'contracts', contractFileName);
const abiPath = path.resolve(process.cwd(), 'build', contractName + '_abi.json');
const bytecodePath = path.resolve(process.cwd(), 'build', contractName + '_bytecode.json');

const methods = {

    compile() {
        const sourceContent = {};
        sourceContent[contractName] =  { content: fs.readFileSync(contractPath, 'utf8') }

        // const libraryContent = {};
        // libraryContent[contractName] = {};
        // libraryContent[contractName][libraryName] = libraryAddress;

        const compilerInputs = {
            language: "Solidity",
            sources: sourceContent,
            settings: {
                optimizer: { "enabled": true, "runs": 1 },
                // libraries: libraryContent,
                outputSelection: { "*": { "*": ["abi", "evm.bytecode"] } }
            }
        };

        const compiledContract = JSON.parse(solc.compile(JSON.stringify(compilerInputs),
                                                        { import: getImports }
                                                        ));
        const contract = compiledContract.contracts[contractName][contractName];

        const abi = contract.abi;
        fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2));

        const bytecode = contract.evm;
        fs.writeFileSync(bytecodePath, JSON.stringify(bytecode, null, 2));
    },

    async deploy(){
        const bytecode = JSON.parse(fs.readFileSync(bytecodePath, 'utf8')).bytecode;
        const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

        const accounts = await web3.eth.getAccounts();

        try{
            const result = await new web3.eth.Contract(abi).deploy({
                data: '0x' + bytecode.object
            })
            .send({
                gas: 8000000,
                gasLimit: 8000000,
                from: accounts[0],
                value: 0
            });

            const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
            config.contractAddress = result.options.address;
            fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
        }catch(error){
            console.log(error);
        }
    },

    getContract(contractName){
        const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
        const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

        return new web3.eth.Contract(abi, config.contractAddress);
    }

}

module.exports = { ...methods }

function getImports(dependency){
    switch(dependency){
        case 'GeneralConfiguration.sol':
            return { contents: fs.readFileSync(path.resolve(process.cwd(), 'contracts', 'GeneralConfiguration.sol'), 'utf8') }
        case libraryName:
            return { contents: fs.readFileSync(path.resolve(process.cwd(), 'contracts', libraryName), 'utf8') }
        default:
            return { error: 'Error on import' }
    }
}