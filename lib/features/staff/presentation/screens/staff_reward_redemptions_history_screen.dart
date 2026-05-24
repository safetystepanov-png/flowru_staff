import 'package:flutter/cupertino.dart';

class StaffRewardRedemptionsHistoryScreen extends StatelessWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffRewardRedemptionsHistoryScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('История наград отключена'),
      ),
      child: Center(
        child: Text('Раздел наград временно отключен'),
      ),
    );
  }
}
