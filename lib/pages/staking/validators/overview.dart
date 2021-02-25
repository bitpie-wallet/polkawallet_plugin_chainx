import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:polkawallet_plugin_chainx/common/components/infoItem.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/actions/bondExtraPage.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/actions/stakePage.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/validators/nominatePage.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/validators/validator.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/validators/validatorDetailPage.dart';
import 'package:polkawallet_plugin_chainx/pages/staking/validators/validatorListFilter.dart';
import 'package:polkawallet_plugin_chainx/polkawallet_plugin_chainx.dart';
import 'package:polkawallet_plugin_chainx/service/walletApi.dart';
import 'package:polkawallet_plugin_chainx/store/staking/types/validatorData.dart';
import 'package:polkawallet_plugin_chainx/utils/format.dart';
import 'package:polkawallet_plugin_chainx/utils/i18n/index.dart';
import 'package:polkawallet_sdk/api/types/staking/ownStashInfo.dart';
import 'package:polkawallet_sdk/storage/keyring.dart';
import 'package:polkawallet_sdk/utils/i18n.dart';
import 'package:polkawallet_ui/components/addressIcon.dart';
import 'package:polkawallet_ui/components/outlinedCircle.dart';
import 'package:polkawallet_ui/components/roundedCard.dart';
import 'package:polkawallet_ui/components/textTag.dart';
import 'package:polkawallet_ui/components/txButton.dart';
import 'package:polkawallet_ui/pages/txConfirmPage.dart';
import 'package:polkawallet_ui/utils/format.dart';
import 'package:polkawallet_ui/utils/i18n.dart';
import 'package:polkawallet_ui/utils/index.dart';

const validator_list_page_size = 100;

class StakingOverviewPage extends StatefulWidget {
  StakingOverviewPage(this.plugin, this.keyring);
  final PluginChainX plugin;
  final Keyring keyring;

  @override
  _StakingOverviewPageState createState() => _StakingOverviewPageState();
}

class _StakingOverviewPageState extends State<StakingOverviewPage> with SingleTickerProviderStateMixin {
  final GlobalKey<RefreshIndicatorState> _refreshKey = new GlobalKey<RefreshIndicatorState>();

  bool _expanded = false;

  bool _loading = false;
  int _sort = 0;
  String _filter = '';

  TabController _tabController;
  int _tab = 0;

  Future<void> _refreshData() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
    });

    _fetchRecommendedValidators();
    widget.plugin.service.staking.queryElectedInfo();
    await widget.plugin.service.staking.queryOwnStashInfo();
  }

  Future<void> _fetchRecommendedValidators() async {
    Map res = await WalletApi.getRecommended();
    if (res != null && res['validators'] != null) {
      widget.plugin.store.staking.setRecommendedValidatorList(res['validators']);
    }
  }

  void _goToBond({bondExtra = false}) {
    if (widget.plugin.store.staking.ownStashInfo == null) return;

    final dic = I18n.of(context).getDic(i18n_full_dic_chainx, 'common');
    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');
    showCupertinoDialog(
      context: context,
      builder: (_) {
        return CupertinoAlertDialog(
          title: Text(dicStaking['action.nominate']),
          content: Text(dicStaking['action.nominate.bond']),
          actions: <Widget>[
            CupertinoButton(
              child: Text(dic['cancel']),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoButton(
              child: Text(dic['ok']),
              onPressed: () async {
                Navigator.of(context).pop();
                final res = Navigator.pushNamed(context, bondExtra ? BondExtraPage.route : StakePage.route);
                if (res != null) {
                  _refreshKey.currentState.show();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _onSetNomination() {
    if (widget.plugin.store.staking.ownStashInfo == null) return;

    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');
    final hasNomination = widget.plugin.store.staking.ownStashInfo.nominating.length > 0;
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text(
              dicStaking['action.nominee'],
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _nominate();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              dicStaking['action.chill'],
              style: TextStyle(color: hasNomination ? Theme.of(context).primaryColor : Theme.of(context).disabledColor),
            ),
            onPressed: hasNomination
                ? () {
                    Navigator.of(context).pop();
                    _chill();
                  }
                : () => null,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(I18n.of(context).getDic(i18n_full_dic_chainx, 'common')['cancel']),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _nominate() async {
    final res = await Navigator.of(context).pushNamed(NominatePage.route);
    if (res != null && res) {
      _refreshKey.currentState.show();
    }
  }

  Future<void> _chill() async {
    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');
    final params = TxConfirmParams(
      txTitle: dicStaking['action.chill'],
      module: 'staking',
      call: 'chill',
      txDisplay: {'action': 'chill'},
      params: [],
    );
    final res = await Navigator.of(context).pushNamed(TxConfirmPage.route, arguments: params);
    if (res != null && res) {
      _refreshKey.currentState.show();
    }
  }

  Widget _buildTopCard(BuildContext context) {
    return RoundedCard(
      margin: EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: EdgeInsets.all(16),
      child: false
          ? Container(
              padding: EdgeInsets.only(top: 80, bottom: 80),
              child: CupertinoActivityIndicator(),
            )
          : Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            "Elector",
                            style: Theme.of(context).textTheme.headline4,
                          ),
                          Text("50 / 124")
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '1,327,631',
                            style: Theme.of(context).textTheme.headline4,
                          ),
                          Text(
                            'Last Block',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                Divider(),
                Text(
                  'Block Producer',
                  style: Theme.of(context).textTheme.headline4,
                ),
                Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                  Container(
                    margin: EdgeInsets.only(right: 16),
                    child: AddressIcon(
                      widget.keyring.current.address,
                      svg: widget.keyring.current.icon,
                    ),
                  ),
                  Text("BEARPOOL")
                ])
              ],
            ),
    );
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(vsync: this, length: 2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');

    List<ValidatorData> validatorsInfo = [];
    Map<String, dynamic> account1 = {
      'accountId': '15fzipQgL4rtnLckM4DiETBNNp3v2bpXguhQxLB6ne6VgXKM',
      'exposure': {'total': 20562449369, 'own': 20441234, 'others': []},
      'isActive': true,
      'isElected': true,
      'numNominators': 0,
      'rankBondTotal': 0,
      'rankReward': 0,
      'stakedReturn': 13.82,
      'stakedReturnCmp': 10.16,
      'validatorPrefs': {'commission': 3000000000},
    };
    validatorsInfo.add(ValidatorData.fromJson(account1));

    return Observer(
      builder: (_) {
        final int decimals = widget.plugin.networkState.tokenDecimals;
        final List<Tab> _listTabs = <Tab>[
          Tab(
            text: '${dicStaking['elected']} (${widget.plugin.store.staking.electedInfo.length})',
          ),
          Tab(
            text: '${dicStaking['waiting']} (${widget.plugin.store.staking.nextUpsInfo.length})',
          ),
        ];
        List list = [
          // index_0: the overview card
          _buildTopCard(context),
          // index_1: the 'Validators' label
        ];
        // if (widget.plugin.store.staking.validatorsInfo.length > 0) {
        if (validatorsInfo.length > 0) {
          // index_2: the filter Widget
          list.add(Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: 8),
            child: ValidatorListFilter(
              needSort: _tab == 0,
              onSortChange: (value) {
                if (value != _sort) {
                  setState(() {
                    _sort = value;
                  });
                }
              },
              onFilterChange: (value) {
                if (value != _filter) {
                  setState(() {
                    _filter = value;
                  });
                }
              },
            ),
          ));
          // index_3: the recommended validators
          // add recommended
          List<ValidatorData> recommended = [];
          final recommendList = widget.plugin.store.staking.recommendedValidators[widget.plugin.basic.name];
          if (recommendList != null) {
            recommended = _tab == 0 ? widget.plugin.store.staking.electedInfo.toList() : widget.plugin.store.staking.nextUpsInfo.toList();
            recommended.retainWhere((i) => widget.plugin.store.staking.recommendedValidators[widget.plugin.basic.name].indexOf(i.accountId) > -1);
          }
          list.add(Container(
            color: Theme.of(context).cardColor,
            child: recommended.length > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextTag(
                        dicStaking['recommend'],
                        color: Colors.green,
                        fontSize: 12,
                        margin: EdgeInsets.only(left: 16, top: 8),
                      ),
                      Column(
                        children: recommended.map((acc) {
                          Map accInfo = widget.plugin.store.accounts.addressIndexMap[acc.accountId];
                          final icon = widget.plugin.store.accounts.addressIconsMap[acc.accountId];
                          return Validator(
                            acc,
                            accInfo,
                            icon,
                            decimals,
                            widget.plugin.store.staking.nominationsMap[acc.accountId] ?? [],
                          );
                        }).toList(),
                      ),
                      Divider()
                    ],
                  )
                : Container(),
          ));
          // add validators
          // List<ValidatorData> ls = _tab == 0 ? widget.plugin.store.staking.electedInfo.toList() : widget.plugin.store.staking.nextUpsInfo.toList();
          List<ValidatorData> ls = validatorsInfo.toList();
          // filter list
          ls = PluginFmt.filterValidatorList(ls, _filter, widget.plugin.store.accounts.addressIndexMap);
          // sort list
          ls.sort((a, b) => PluginFmt.sortValidatorList(widget.plugin.store.accounts.addressIndexMap, a, b, _sort));
          if (_tab == 1) {
            ls.sort((a, b) {
              final aLength = widget.plugin.store.staking.nominationsMap[a.accountId]?.length ?? 0;
              final bLength = widget.plugin.store.staking.nominationsMap[b.accountId]?.length ?? 0;
              return 0 - aLength.compareTo(bLength);
            });
          }
          list.addAll(ls);
        } else {
          list.add(Container(
            height: 160,
            child: CupertinoActivityIndicator(),
          ));
        }
        return RefreshIndicator(
          key: _refreshKey,
          onRefresh: _refreshData,
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) {
              // we already have the index_0 - index_3 Widget
              if (i < 4) {
                return list[i];
              }
              ValidatorData acc = list[i];
              Map accInfo = widget.plugin.store.accounts.addressIndexMap[acc.accountId];
              final icon = widget.plugin.store.accounts.addressIconsMap[acc.accountId];
              return Validator(
                acc,
                accInfo,
                icon,
                decimals,
                widget.plugin.store.staking.nominationsMap[acc.accountId] ?? [],
              );
            },
          ),
        );
      },
    );
  }
}

enum NomStatus { active, over, inactive, waiting }

class _NomineeItem extends StatelessWidget {
  _NomineeItem(
    this.id,
    this.validators,
    this.stashId,
    this.nomStatus,
    this.decimals,
    this.accInfoMap,
    this.accIconMap,
  );

  final String id;
  final List<ValidatorData> validators;
  final String stashId;
  final NomStatus nomStatus;
  final int decimals;
  final Map<String, Map> accInfoMap;
  final Map<String, String> accIconMap;

  @override
  Widget build(BuildContext context) {
    final dicStaking = I18n.of(context).getDic(i18n_full_dic_chainx, 'staking');

    final validatorIndex = validators.indexWhere((i) => i.accountId == id);
    final validator = validatorIndex < 0 ? ValidatorData.fromJson({'accountId': id}) : validators[validatorIndex];

    final accInfo = accInfoMap[validator.accountId];
    final icon = accIconMap[validator.accountId];
    final status = nomStatus.toString().split('.')[1];

    BigInt meStaked;
    int meIndex = validator.nominators.indexWhere((i) => i['who'] == stashId);
    if (meIndex >= 0) {
      meStaked = BigInt.parse(validator.nominators[meIndex]['value'].toString());
    }
    String subtitle = dicStaking['nominate.$status'];
    if (nomStatus == NomStatus.active) {
      subtitle += ' ${Fmt.token(meStaked ?? BigInt.zero, decimals)}';
    }

    return ListTile(
      dense: true,
      leading: AddressIcon(validator.accountId, svg: icon, size: 32),
      title: UI.accountDisplayName(validator.accountId, accInfo),
      subtitle: Text(subtitle),
      trailing: Container(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(
              child: Container(height: 4),
            ),
            Expanded(
              child: Text(validator.commission.isNotEmpty ? validator.commission : '~'),
            ),
            Expanded(
              child: Text(dicStaking['commission'], style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).pushNamed(ValidatorDetailPage.route, arguments: validator);
      },
    );
  }
}
