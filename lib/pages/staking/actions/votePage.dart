import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/actions/setPayeePage.dart';
import 'package:polkawallet_plugin_chainx/polkawallet_plugin_chainx.dart';
import 'package:polkawallet_plugin_chainx/utils/i18n/index.dart';
import 'package:polkawallet_sdk/storage/keyring.dart';
import 'package:polkawallet_sdk/storage/types/keyPairData.dart';
import 'package:polkawallet_sdk/utils/i18n.dart';
import 'package:polkawallet_ui/components/addressFormItem.dart';
import 'package:polkawallet_ui/components/roundedButton.dart';
import 'package:polkawallet_ui/components/textTag.dart';
import 'package:polkawallet_ui/components/txButton.dart';
import 'package:polkawallet_ui/pages/accountListPage.dart';
import 'package:polkawallet_ui/utils/format.dart';
import 'package:polkawallet_ui/utils/index.dart';

class VotePage extends StatefulWidget {
  VotePage(this.plugin, this.keyring, this.validatorAccountId, {this.onNext});
  final PluginChainX plugin;
  final Keyring keyring;
  final String validatorAccountId;
  final Function(TxConfirmParams) onNext;
  @override
  _VotePageState createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountCtrl = new TextEditingController();

  final _rewardToOptions = ['Staked', 'Stash', 'Controller'];

  KeyPairData _controller;

  int _rewardTo = 0;
  String _rewardAccount;

  Future<void> _changeControllerId(BuildContext context) async {
    final accounts = widget.keyring.keyPairs.toList();
    accounts.addAll(widget.keyring.externals);
    final acc = await Navigator.of(context).pushNamed(
      AccountListPage.route,
      arguments: AccountListPageParams(list: accounts),
    );
    if (acc != null) {
      setState(() {
        _controller = acc;
      });
    }
  }

  void _onPayeeChanged(int to, String address) {
    setState(() {
      _rewardTo = to;
      _rewardAccount = address;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dic = I18n.of(context).getDic(i18n_full_dic_chainx, 'common');
    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');
    final symbol = widget.plugin.networkState.tokenSymbol;
    final decimals = widget.plugin.networkState.tokenDecimals;

    double available = 0;
    if (widget.plugin.balances.native != null) {
      available = Fmt.balanceDouble(widget.plugin.balances.native.availableBalance.toString(), decimals);
    }

    final rewardToOptions = _rewardToOptions.map((i) => dicStaking['reward.$i']).toList();

    List<KeyPairData> accounts;
    if (_rewardTo == 3) {
      accounts = widget.keyring.keyPairs;
      accounts.addAll(widget.keyring.externals);
    }

    List<KeyPairData> filter = widget.keyring.allAccounts.where((i) => i.address == widget.validatorAccountId).toList();
    KeyPairData validatorKeyPair = filter.isNotEmpty ? filter.first : KeyPairData();

    return Column(
      children: <Widget>[
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  child: AddressFormItem(
                    widget.keyring.current,
                    label: dicStaking['mystaking.action.vote.myaccount'],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  child: AddressFormItem(
                    validatorKeyPair,
                    label: dicStaking['mystaking.action.vote.validator'],
                    // do not allow change controller here.
                    // onTap: () => _changeControllerId(context),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: dic['amount'],
                      labelText: '${dic['amount']} (${dicStaking['available']}: ${Fmt.priceFloor(
                        available,
                        lengthMax: 3,
                      )} $symbol)',
                    ),
                    inputFormatters: [UI.decimalInputFormatter(decimals)],
                    controller: _amountCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v.isEmpty) {
                        return dic['amount.error'];
                      }
                      // if (double.parse(v.trim()) >= available) {
                      //   return dic['amount.low'];
                      // }
                      return null;
                    },
                  ),
                ),
                // PayeeSelector(
                //   widget.plugin,
                //   widget.keyring,
                //   initialValue: widget.plugin.store.staking.ownStashInfo,
                //   onChange: _onPayeeChanged,
                // ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16),
          child: RoundedButton(
            text: dicStaking['mystaking.action.vote.label'],
            onPressed: () {
              if (_formKey.currentState.validate()) {
                final inputAmount = _amountCtrl.text.trim();
                String controllerId = widget.keyring.current.address;
                if (_controller != null) {
                  controllerId = _controller.address;
                }
                widget.onNext(TxConfirmParams(
                  txTitle: dicStaking['mystaking.action.vote.label'],
                  module: 'staking',
                  call: 'bond',
                  txDisplay: {
                    "amount": '$inputAmount $symbol',
                    "reward_destination": _rewardTo == 3 ? {'Account': _rewardAccount} : rewardToOptions[_rewardTo],
                  },
                  params: [
                    // "controllerId":
                    controllerId,
                    // "amount"
                    Fmt.tokenInt(inputAmount, decimals).toString(),
                    // "to"
                    _rewardTo == 3 ? {'Account': _rewardAccount} : _rewardTo,
                  ],
                ));
              }
            },
          ),
        ),
      ],
    );
  }
}