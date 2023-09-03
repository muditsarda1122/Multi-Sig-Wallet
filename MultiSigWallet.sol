//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 txId);
    event Revoke(address indexed owner, uint256 txId);
    event Execute(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] owners;
    mapping(address => bool) public isOwner;
    uint256 public minRequired;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not the owner");
        _;
    }

    modifier txExist(uint256 _txId) {
        require(_txId < transactions.length, "transaction does not exist");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "transction already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _minRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _minRequired > 0 && _minRequired <= _owners.length,
            "invalid required number of owners"
        );

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        minRequired = _minRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );

        emit Submit(transactions.length - 1);
    }

    function approve(
        uint256 _txId
    ) external txExist(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(
        uint256 _txId
    ) private view returns (uint256 count) {
        for (uint256 i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint256 _txId) external txExist(_txId) notExecuted(_txId) {
        require(
            _getApprovalCount(_txId) >= minRequired,
            "not enough approvals"
        );
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        require(success, "transaction failed");

        emit Execute(_txId);
    }

    function revoke(
        uint256 _txId
    ) external onlyOwner txExist(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "transaction not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
