import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import RiideToken "canister:riide_token";

actor class Staking() = this {
  type Stake = {
    amount : Nat;
    staked_at : Int;
    duration : Nat;
  };

  private stable var stakes = HashMap.HashMap<Principal, Stake>(1, Principal.equal, Principal.hash);

  public shared({ caller }) func stake(amount : Nat, duration : Nat) : async () {
    assert(amount >= 1000_00000000);
    await RiideToken.icrc1_transfer({
      to = { owner = Principal.fromActor(this) };
      amount;
      fee = 0;
    });
    stakes.put(caller, {
      amount;
      staked_at = Time.now();
      duration;
    });
  };

  public shared query func get_staked_amount(user : Principal) : async Nat {
    Option.get(Option.map(stakes.get(user), func (s : Stake) : Nat { s.amount }), 0)
  };
};