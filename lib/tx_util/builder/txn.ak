//// Usage example,
//// ```
//// test positive_case() {
////   // Arrange:
////   let nft = from_asset("NftPolicy", "NftName", 1)
////   let token = from_asset("TokenPolicy", "TokenName", 10)
////   // use cardano/assets.{from_asset}
////   let asset_1 = from_asset("AssetPolicy1", "AssetName1", 1)
////   let asset_2 = from_asset("AssetPolicy2", "AssetName2", 1000)
////   let asset_2_partial = from_asset("AssetPolicy2", "AssetName2", 100)
////
////   // tx_util/builder/txn:
////   let tx_ref_in =
////     new_tx_input(
////       output_reference: OutputReference("TxRefInHash", 0),
////       address: "VerificationKeyHash" |> from_verification_key,
////     )
////       |> with_asset_of_tx_input(2_000_000 |> from_lovelace)
////       |> with_asset_of_tx_input(token)
////
////   let tx_in =
////     new_tx_input(
////       output_reference: OutputReference("TxInHash", 1),
////       address: "ScriptHash" |> from_script,
////     )
////       |> set_datum_of_tx_input("OldDatum" |> InlineDatum)
////       |> with_asset_of_tx_input(4_000_000 |> from_lovelace)
////       |> with_asset_of_tx_input(nft)
////       |> with_asset_of_tx_input(asset_1)
////       |> with_asset_of_tx_input(asset_2)
////
////   let tx_out =
////     new_tx_output(address: "ValidatorHash" |> from_script)
////       |> set_datum_of_tx_output("NewDatum" |> InlineDatum)
////       |> add_asset_to_tx_output(4_000_000 |> from_lovelace)
////       |> add_asset_to_tx_output(nft)
////       |> add_asset_to_tx_output(asset_1)
////       |> add_asset_to_tx_output(asset_2_partial)
////
////   let tx =
////     transaction.placeholder
////       |> add_tx_ref_input(tx_ref_in)
////       |> add_tx_input(tx_in)
////       |> add_tx_output(tx_out)
////       |> add_signatory("PubKeyHash")
////
////   // Trace:
////   trace @"Tx": tx
////
////   // Assert:
////   vallidator.validate.spend(None, Void, output_reference, tx)
//// }
//// ```

use aiken/collection/dict.{insert}
use aiken/collection/list.{concat}
use aiken/collection/pairs.{repsert_by_ascending_key}
use aiken/crypto.{DataHash, ScriptHash, VerificationKeyHash}
use cardano/address.{Address}
use cardano/address/credential
use cardano/assets.{merge}
use cardano/certificate.{Certificate}
use cardano/governance.{GovernanceAction, GovernanceActionId, ProposalProcedure}
use cardano/governance/voter
use cardano/transaction.{
  NoDatum, OutputReference, ScriptPurpose, Transaction, TransactionId,
  ValidityRange,
}
use cardano/transaction/script_purpose

/// Set `Transaction.id`.
/// The default value is `#"0000000000000000000000000000000000000000000000000000000000000000"`
pub fn set_id(tx: Transaction, id: TransactionId) -> Transaction {
  Transaction { ..tx, id: id }
}

/// Set `Transaction.validity_range`.
/// The default value is `interval.everything`
pub fn set_validity_range(
  tx: Transaction,
  validity_range: ValidityRange,
) -> Transaction {
  Transaction { ..tx, validity_range: validity_range }
}

/// Set `Transaction.fee`.
/// The default value is `0`
pub fn set_fee(tx: Transaction, fee: assets.Lovelace) -> Transaction {
  Transaction { ..tx, fee: fee }
}

// ## Add Transaction Input

/// Concat `tx_in` to `Transaction.inputs`.
/// The new `tx_in` is placed at the end of the list.
///
/// Example,
/// ```
/// let tx_in = new_tx_input(...)
///     |> set_datum_of_tx_input(...)
///     |> attach_ref_script_to_tx_input(...)
///     |> with_asset_of_tx_input(...)
///     |> with_asset_of_tx_input(...)
///
/// let txn = transaction.placeholder
///     |> add_tx_input(tx_in)
/// ```
pub fn add_tx_input(tx: Transaction, tx_in: transaction.Input) -> Transaction {
  Transaction { ..tx, inputs: tx.inputs |> concat([tx_in]) }
}

// ### Construct Transaction Input

/// Initialize a transaction input with zero assets value, no datum, and no reference script.
///
/// Example,
/// ```
/// let output_reference = OutputReference(#"0000000000000000000000000000000000000000000000000000000000000064", 0)
/// let address = from_verification_key(#"00000000000000000000000000000000000000000000000000000056")
///
/// let tx_in = new_tx_input(output_reference, address)
/// ```
pub fn new_tx_input(
  output_reference: OutputReference,
  address: Address,
) -> transaction.Input {
  transaction.Input {
    output_reference,
    output: transaction.Output {
      address,
      value: assets.zero,
      datum: NoDatum,
      reference_script: None,
    },
  }
}

/// Add an asset to a transaction input.
///
/// Example,
/// ```
/// let tx_in = new_tx_input(output_reference, address)
///     |> with_asset_of_tx_input(from_lovelace(2_000_000))
///     |> with_asset_of_tx_input(from_asset("PolicyId1", "Nft1", 1))
///     |> with_asset_of_tx_input(from_asset("PolicyId1", "Token1", 3_000))
///     |> with_asset_of_tx_input(from_asset("PolicyId2", "Nft2", 1))
/// ```
pub fn with_asset_of_tx_input(
  input: transaction.Input,
  asset: assets.Value,
) -> transaction.Input {
  transaction.Input {
    ..input,
    output: transaction.Output {
      ..input.output,
      value: input.output.value |> merge(asset),
    },
  }
}

/// Set a datum of a transaction input.
///
/// Example,
/// ```
/// let tx_in = new_tx_input(output_reference, address)
///     |> set_datum_of_tx_input(InlineDatum(...))
/// ```
pub fn set_datum_of_tx_input(
  input: transaction.Input,
  datum: transaction.Datum,
) -> transaction.Input {
  transaction.Input {
    ..input,
    output: transaction.Output { ..input.output, datum: datum },
  }
}

/// Attach a reference script to a transaction input.
///
/// Example,
/// ```
/// let tx_in = new_tx_input(output_reference, address)
///     |> attach_ref_script_to_tx_input(#"00000000000000000000000000000000000000000000000000000056")
/// ```
pub fn attach_ref_script_to_tx_input(
  input: transaction.Input,
  ref_script: ScriptHash,
) -> transaction.Input {
  transaction.Input {
    ..input,
    output: transaction.Output {
      ..input.output,
      reference_script: Some(ref_script),
    },
  }
}

/// Remove reference script from a transaction input.
///
/// Example,
/// ```
/// let tx_in = new_tx_input(output_reference, address)
///     |> attach_ref_script_to_tx_input(#"00000000000000000000000000000000000000000000000000000056")
///     |> remove_ref_script_from_tx_input()
/// ```
pub fn remove_ref_script_from_tx_input(
  input: transaction.Input,
) -> transaction.Input {
  transaction.Input {
    ..input,
    output: transaction.Output { ..input.output, reference_script: None },
  }
}

// ## Add Reference Input

/// Concat `tx_ref_in` to `Transaction.reference_inputs`.
/// The new `tx_ref_in` is placed at the end of the list.
///
/// Example,
/// ```
/// let tx_ref_in = new_tx_input(...)
///     |> set_datum_of_tx_input(...)
///     |> attach_ref_script_to_tx_input(...)
///     |> with_asset_of_tx_input(...)
///     |> with_asset_of_tx_input(...)
///
/// let txn = transaction.placeholder
///     |> add_tx_ref_input(tx_ref_in)
/// ```
pub fn add_tx_ref_input(
  tx: Transaction,
  tx_ref_in: transaction.Input,
) -> Transaction {
  Transaction {
    ..tx,
    reference_inputs: tx.reference_inputs |> concat([tx_ref_in]),
  }
}

// ## Add Transaction Output

/// Concat `tx_out` to `Transaction.outputs`.
/// The new `tx_out` is placed at the end of the list.
///
/// Example,
/// ```
/// let tx_out = new_tx_output(...)
///     |> set_datum_of_tx_output(...)
///     |> attach_ref_script_to_tx_output(...)
///     |> add_asset_to_tx_output(...)
///     |> add_asset_to_tx_output(...)
///
/// let txn = transaction.placeholder
///     |> add_tx_output(tx_out)
/// ```
pub fn add_tx_output(tx: Transaction, tx_out: transaction.Output) -> Transaction {
  Transaction { ..tx, outputs: tx.outputs |> concat([tx_out]) }
}

// ### Construct Transaction Output

/// Initialize a transaction output with zero assets value, no datum, and no reference script.
///
/// Example,
/// ```
/// let address = from_script(#"00000000000000000000000000000000000000000000000000000056")
/// let tx_out = new_tx_output(address)
/// ```
pub fn new_tx_output(address: Address) -> transaction.Output {
  transaction.Output {
    address,
    value: assets.zero,
    datum: NoDatum,
    reference_script: None,
  }
}

/// Add an asset to a transaction output.
///
/// Example,
/// ```
/// let tx_out = new_tx_output(address)
///     |> add_asset_to_tx_output(from_lovelace(2_000_000))
///     |> add_asset_to_tx_output(from_asset("PolicyId1", "Nft1", 1))
///     |> add_asset_to_tx_output(from_asset("PolicyId1", "Token1", 3_000))
///     |> add_asset_to_tx_output(from_asset("PolicyId2", "Nft2", 1))
/// ```
pub fn add_asset_to_tx_output(
  output: transaction.Output,
  asset: assets.Value,
) -> transaction.Output {
  transaction.Output { ..output, value: output.value |> merge(asset) }
}

/// Set a datum of a transaction output.
///
/// Example,
/// ```
/// let tx_out = new_tx_output(address)
///     |> set_datum_of_tx_output(InlineDatum(...))
/// ```
pub fn set_datum_of_tx_output(
  output: transaction.Output,
  datum: transaction.Datum,
) -> transaction.Output {
  transaction.Output { ..output, datum: datum }
}

/// Attach a reference script to a transaction output.
///
/// Example,
/// ```
/// let tx_out = new_tx_output(address)
///     |> attach_ref_script_to_tx_output(#"00000000000000000000000000000000000000000000000000000056")
/// ```
pub fn attach_ref_script_to_tx_output(
  output: transaction.Output,
  ref_script: ScriptHash,
) -> transaction.Output {
  transaction.Output { ..output, reference_script: Some(ref_script) }
}

/// Remove reference script from a transaction output.
///
/// Example,
/// ```
/// let tx_out = new_tx_output(address)
///     |> attach_ref_script_to_tx_output(#"00000000000000000000000000000000000000000000000000000056")
///     |> remove_ref_script_from_tx_output()
/// ```
pub fn remove_ref_script_from_tx_output(
  output: transaction.Output,
) -> transaction.Output {
  transaction.Output { ..output, reference_script: None }
}

// ## Mints

/// Merge `asset` to `Transaction.mint`
pub fn add_mint(tx: Transaction, asset: assets.Value) -> Transaction {
  Transaction { ..tx, mint: tx.mint |> merge(asset) }
}

// ## Certificates

/// Concat `certificate` to `Transaction.certificates`.
/// The new value is placed at the end of the list.
pub fn add_certificate(tx: Transaction, certificate: Certificate) -> Transaction {
  Transaction { ..tx, certificates: tx.certificates |> concat([certificate]) }
}

// ## Withdrawals

/// https://github.com/aiken-lang/stdlib/blob/0c2851f45cdad0d23a94f0cba149891a358e7637/lib/aiken/collection/pairs.ak#L589-L609
fn merge_withdrawal(
  withdrawals: Pairs<address.Credential, assets.Lovelace>,
  withdrawal: Pair<address.Credential, assets.Lovelace>,
) -> Pairs<address.Credential, assets.Lovelace> {
  when withdrawals is {
    [] ->
      [withdrawal]

    [current, ..next] -> {
      let Pair(current_credential, current_lovelace) = current
      let Pair(withdrawal_credential, withdrawal_lovelace) = withdrawal

      when withdrawal_credential |> credential.compare(current_credential) is {
        Less ->
          [withdrawal, ..withdrawals]

        Equal -> {
          let total_lovelace = current_lovelace + withdrawal_lovelace
          [Pair(current_credential, total_lovelace), ..next]
        }

        Greater ->
          [current, ..next |> merge_withdrawal(withdrawal)]
      }
    }
  }
}

test testing_merge_withdrawal() {
  expect [Pair(address.Script("a"), 1)] =
    [] |> merge_withdrawal(Pair(address.Script("a"), 1))

  expect [Pair(address.Script("a"), 3)] =
    [Pair(address.Script("a"), 1)]
      |> merge_withdrawal(Pair(address.Script("a"), 2))

  expect [Pair(address.Script("a"), 1), Pair(address.Script("b"), 1)] =
    [Pair(address.Script("a"), 1)]
      |> merge_withdrawal(Pair(address.Script("b"), 1))

  expect [Pair(address.Script("a"), 1), Pair(address.VerificationKey("a"), 1)] =
    [Pair(address.Script("a"), 1)]
      |> merge_withdrawal(Pair(address.VerificationKey("a"), 1))

  expect [Pair(address.Script("a"), 2), Pair(address.VerificationKey("a"), 1)] =
    [Pair(address.VerificationKey("a"), 1)]
      |> merge_withdrawal(Pair(address.Script("a"), 2))

  expect [
    Pair(address.VerificationKey("a"), 1),
    Pair(address.VerificationKey("b"), 2),
  ] =
    [Pair(address.VerificationKey("b"), 2)]
      |> merge_withdrawal(Pair(address.VerificationKey("a"), 1))

  expect [Pair(address.VerificationKey("a"), 2)] =
    [Pair(address.VerificationKey("a"), 1)]
      |> merge_withdrawal(Pair(address.VerificationKey("a"), 1))

  let withdrawals =
    [
      Pair(address.Script("a"), 1),
      Pair(address.Script("b"), 2),
      Pair(address.Script("c"), 3),
      Pair(address.VerificationKey("d"), 4),
      Pair(address.VerificationKey("e"), 5),
      Pair(address.VerificationKey("f"), 6),
    ]

  expect [
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 2),
    Pair(address.Script("c"), 3),
    Pair(address.Script("d"), 7),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 5),
    Pair(address.VerificationKey("f"), 6),
  ] = withdrawals |> merge_withdrawal(Pair(address.Script("d"), 7))

  expect [
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 2),
    Pair(address.Script("c"), 3),
    Pair(address.VerificationKey("c"), 7),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 5),
    Pair(address.VerificationKey("f"), 6),
  ] = withdrawals |> merge_withdrawal(Pair(address.VerificationKey("c"), 7))

  expect [
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 9),
    Pair(address.Script("c"), 3),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 5),
    Pair(address.VerificationKey("f"), 6),
  ] = withdrawals |> merge_withdrawal(Pair(address.Script("b"), 7))

  expect [
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 2),
    Pair(address.Script("c"), 3),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 12),
    Pair(address.VerificationKey("f"), 6),
  ] = withdrawals |> merge_withdrawal(Pair(address.VerificationKey("e"), 7))

  expect [
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 2),
    Pair(address.Script("c"), 3),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 5),
    Pair(address.VerificationKey("f"), 6),
    Pair(address.VerificationKey("g"), 7),
  ] = withdrawals |> merge_withdrawal(Pair(address.VerificationKey("g"), 7))

  expect [
    Pair(address.Script(""), 7),
    Pair(address.Script("a"), 1),
    Pair(address.Script("b"), 2),
    Pair(address.Script("c"), 3),
    Pair(address.VerificationKey("d"), 4),
    Pair(address.VerificationKey("e"), 5),
    Pair(address.VerificationKey("f"), 6),
  ] = withdrawals |> merge_withdrawal(Pair(address.Script(""), 7))
}

/// Merge `withdrawal` to `Transaction.withdrawals`
pub fn add_withdrawal(
  tx: Transaction,
  withdrawal_key: address.Credential,
  withdrawal_value: assets.Lovelace,
) -> Transaction {
  Transaction {
    ..tx,
    withdrawals: tx.withdrawals
      |> merge_withdrawal(Pair(withdrawal_key, withdrawal_value)),
  }
}

// ## Sign Transaction

/// Concat `signatory` to `Transaction.extra_signatories`.
/// The new value is placed at the end of the list.
pub fn add_signatory(
  tx: Transaction,
  signatory: VerificationKeyHash,
) -> Transaction {
  Transaction {
    ..tx,
    extra_signatories: tx.extra_signatories |> concat([signatory]),
  }
}

// ## Datums and Redeemers

/// Insert `datum` to `Transaction.datums`.
/// If the key already exists, its value is overridden.
pub fn add_datum(
  tx: Transaction,
  datum_key: DataHash,
  datum_value: Data,
) -> Transaction {
  Transaction {
    ..tx,
    datums: tx.datums |> insert(key: datum_key, value: datum_value),
  }
}

/// Repsert `redeemer` to `Transaction.redeemers`.
/// If the key already exists, its value is replaced.
pub fn add_redeemer(
  tx: Transaction,
  redeemer_key: ScriptPurpose,
  redeemer_value: transaction.Redeemer,
) -> Transaction {
  Transaction {
    ..tx,
    redeemers: tx.redeemers
      |> repsert_by_ascending_key(
          key: redeemer_key,
          value: redeemer_value,
          compare: script_purpose.compare,
        ),
  }
}

// ## Governance

/// Repsert `vote` to `Transaction.votes`.
/// If the key already exists, its value is replaced.
pub fn add_vote(
  tx: Transaction,
  vote_key: governance.Voter,
  vote_value: Pairs<GovernanceActionId, governance.Vote>,
) -> Transaction {
  Transaction {
    ..tx,
    votes: tx.votes
      |> repsert_by_ascending_key(
          key: vote_key,
          value: vote_value,
          compare: voter.compare,
        ),
  }
}

/// Concat `proposal_procedure` to `Transaction.proposal_procedures`.
/// The new value is placed at the end of the list.
pub fn add_proposal_procedure(
  tx: Transaction,
  deposit: assets.Lovelace,
  return_address: address.Credential,
  governance_action: GovernanceAction,
) -> Transaction {
  Transaction {
    ..tx,
    proposal_procedures: tx.proposal_procedures
      |> concat([ProposalProcedure(deposit, return_address, governance_action)]),
  }
}

// ## Treasury

// ### Current Treasury Amount

/// Set `Transaction.current_treasury_amount`
pub fn set_current_treasury_amount(
  tx: Transaction,
  amount: assets.Lovelace,
) -> Transaction {
  Transaction { ..tx, current_treasury_amount: Some(amount) }
}

/// Unset `Transaction.current_treasury_amount`
pub fn unset_current_treasury_amount(tx: Transaction) -> Transaction {
  Transaction { ..tx, current_treasury_amount: None }
}

// ### Treasury Donation

/// Set `Transaction.treasury_donation`
pub fn set_treasury_donation(
  tx: Transaction,
  donation: assets.Lovelace,
) -> Transaction {
  Transaction { ..tx, treasury_donation: Some(donation) }
}

/// Unset `Transaction.treasury_donation`
pub fn unset_treasury_donation(tx: Transaction) -> Transaction {
  Transaction { ..tx, treasury_donation: None }
}
