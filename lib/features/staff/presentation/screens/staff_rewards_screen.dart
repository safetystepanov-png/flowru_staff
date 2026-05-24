import 'package:flutter/cupertino.dart';

class StaffRewardsScreen extends StatelessWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffRewardsScreen({
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
        middle: Text('Награды отключены'),
      ),
      child: Center(
        child: Text('Раздел наград временно отключен'),
      ),
    );
  }
}
