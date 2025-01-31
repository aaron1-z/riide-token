import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Time "mo:base/Time";
import ICRC1 "mo:icrc1/ICRC1";

shared({ caller = deployer }) actor class RiideToken(
  initial_holders : [(Principal, Nat)],
  fee_collector : Principal,
  dao_controller : Principal
) = this {
  // Token configuration
  let TOKEN_NAME = "RIIDE";
  let TOKEN_SYMBOL = "RIIDE";
  let DECIMALS : Nat8 = 8;
  let FEE : Nat = 10_000;
  let MAX_SUPPLY : Nat = 1_000_000_000 * 10 ** Nat.fromNat8(DECIMALS);

  // Stable state
  private stable var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
  private stable var metadata : [ICRC1.MetaDatum] = [
    ("icrc1:name", #Text(TOKEN_NAME)),
    ("icrc1:symbol", #Text(TOKEN_SYMBOL)),
    ("icrc1:decimals", #Nat(Nat.fromNat8(DECIMALS))),
    ("icrc1:fee", #Nat(FEE)),
  ];

  // Initialization
  system func preupgrade() = balances := HashMap.fromIter<Principal, Nat>(balances.entries(), 1, Principal.equal, Principal.hash);
  system func postupgrade() = ();

  for ((owner, amount) in initial_holders.vals()) {
    balances.put(owner, amount);
  };

  // ICRC1 Interface
  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] { metadata };
  public shared query func icrc1_total_supply() : async Nat { MAX_SUPPLY };
  public shared query func icrc1_balance_of(args : ICRC1.Account) : async Nat {
    Option.get(balances.get(args.owner), 0)
  };

  public shared({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
    let from = caller;
    let to = args.to.owner;
    let amount = args.amount;

    if (amount == 0 or args.fee != FEE) return #Err(#BadFee);
    if (_get_balance(from) < amount + FEE) return #Err(#InsufficientFunds);

    _update_balance(from, -Nat.sub(amount + FEE, 0));
    _update_balance(to, amount);
    _update_balance(fee_collector, FEE);
    #Ok(args.amount);
  };

  // DAO functions
  public shared({ caller }) func mint(to : Principal, amount : Nat) : async Result.Result<(), Text> {
    if (caller != dao_controller) return #Err("Unauthorized");
    _update_balance(to, amount);
    #Ok()
  };

  // Internal utilities
  func _get_balance(owner : Principal) : Nat = Option.get(balances.get(owner), 0);
  func _update_balance(owner : Principal, delta : Int) {
    let current = _get_balance(owner);
    let new_balance = current + delta;
    if (new_balance < 0) trap("Balance underflow");
    balances.put(owner, new_balance);
  };
};