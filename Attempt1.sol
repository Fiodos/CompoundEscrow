pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RequestFactory {
    ReceivePayment[] public deployedRequests;

    function createRequest(address token, uint amount, address logisticsP) public {
        ReceivePayment newRequest = new ReceivePayment(token, amount, msg.sender, logisticsP);
        deployedRequests.push(newRequest);
    }

    function getDeployedRequests() public view returns (ReceivePayment[] memory) {
        return deployedRequests;
    }
}


interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
    
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool); 
}


contract ReceivePayment {
    uint public amount;
    address payable public seller;
    address payable public buyer;
    address public forwarder;
    address public token;

    enum State { Created, Locked, Closed }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    // Only the buyer can call this function.
    error OnlyForwarder();
    // Only the seller can call this function.
    error OnlySeller();
    // The function cannot be called at the current state.
    error InvalidState();


    modifier restrictedSeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier restrictedForwarder() {
        if (msg.sender != forwarder)
            revert OnlyForwarder();
        _;
    }

    modifier inState(State _state) {
        if (state != _state)
            revert InvalidState();
        _;
    }
    
   

    event Aborted();
    event PurchaseConfirmed();
    event ItemDelivered();
    event MyLog(string, uint256);


    constructor(address _token, uint _amount, address creator, address logisticsP) payable {
        seller = payable(creator);
        forwarder = logisticsP;
        amount = _amount;
        token = _token;
    }
    // Abort the purchase and reclaim the ether.
    // Can only be called by the seller before the contract is locked.
    function abort() public restrictedSeller inState(State.Created) {
        emit Aborted();
        state = State.Closed;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    // Confirm the purchase as buyer.
    // Transaction has to include value ether.
    // The ether will be locked until releasePayment is called.
    function confirmPurchase() public inState(State.Created) payable {
        Erc20(token).approve( address(this), amount);
        Erc20(token).transfer( address(this), amount);
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
    }

    // Logistics partner confirms that goods have been delivered and signals money release
    function releasePayment() public restrictedForwarder {
        emit ItemDelivered();
        state = State.Closed;
        seller.transfer(amount);
    }
}
