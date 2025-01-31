import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import RiideToken "canister:riide_token";
import Staking "canister:staking";

actor class DAO() = this {
  type Proposal = {
    id : Nat;
    title : Text;
    description : Text;
    votes_for : Nat;
    votes_against : Nat;
    executed : Bool;
  };

  private stable var next_id : Nat = 1;
  private stable var proposals = HashMap.HashMap<Nat, Proposal>(1, Nat.equal, Hash.hash);

  public shared({ caller }) func submit_proposal(title : Text, description : Text) : async Nat {
    let id = next_id;
    proposals.put(id, {
      id;
      title;
      description;
      votes_for = 0;
      votes_against = 0;
      executed = false;
    });
    next_id += 1;
    id
  };

  public shared({ caller }) func vote(proposal_id : Nat, support : Bool) : async () {
    let balance = await RiideToken.icrc1_balance_of({ owner = caller });
    let staked = await Staking.get_staked_amount(caller);
    let voting_power = balance + staked;

    switch (proposals.get(proposal_id)) {
      case (?prop) {
        let updated = if (support) {
          { prop with votes_for = prop.votes_for + voting_power }
        } else {
          { prop with votes_against = prop.votes_against + voting_power }
        };
        proposals.put(proposal_id, updated);
      };
      case null ();
    };
  };
};