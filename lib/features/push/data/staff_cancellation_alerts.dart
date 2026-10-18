import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffCancellationAlerts {
 static GlobalKey<NavigatorState>? _navigator;
 static Future<void>? _initializing;
 static SharedPreferences? _preferences;
 static final _acknowledged = <String>{};
 static final _pending = <String,Map<String,dynamic>>{};
 static bool _showing = false;
 static bool _ackInFlight = false;
 static Future<void> _writes = Future.value();
 static const _ackKey = 'flowru_cancel_ack_v1';
 static const _pendingKey = 'flowru_cancel_pending_v1';
 static Future<void> _ready() => _initializing ??= _initialize();
 static Future<void> _initialize() async {
  _preferences = await SharedPreferences.getInstance();
  _acknowledged.addAll(_preferences!.getStringList(_ackKey) ?? []);
  try {
   final data=jsonDecode(_preferences!.getString(_pendingKey) ?? '{}');
   if(data is Map) for(final entry in data.entries) {
    if(entry.value is Map && !_acknowledged.contains(entry.key)) _pending[entry.key.toString()]=Map<String,dynamic>.from(entry.value);
   }
  } catch (_) { /* A malformed old cache must not prevent incoming warnings. */ }
 }
 static void attach(GlobalKey<NavigatorState> navigator) {
  _navigator=navigator;
  WidgetsBinding.instance.addPostFrameCallback((_) async {await _ready();unawaited(_drain());});
 }
 static Future<void> receive(Map<String,dynamic> data,{bool force=false}) async {
  if(data['type']!='preorder_cancelled') return;
  final id=int.tryParse('${data['preorder_id']}');
  final est=int.tryParse('${data['establishment_id']}');
  if(id==null || est==null)return;
  await _ready();
  final key='$est:$id';
  if(_pending.containsKey(key) || (!force && _acknowledged.contains(key)))return;
  if(force)_acknowledged.remove(key);
  _pending[key]={'preorder_id':id,'establishment_id':est};
  await _savePending();
  unawaited(_drain());
 }
 static Future<void> _savePending() {
  _writes=_writes.catchError((Object _) {}).then((_) async {
   await _preferences!.setString(_pendingKey,jsonEncode(_pending));
  });
  return _writes;
 }
 static Future<void> _drain() async {
  if(_showing || _pending.isEmpty)return;
  final context=_navigator?.currentState?.overlay?.context;
  if(context==null)return;
  _showing=true;
  try {
   while(_pending.isNotEmpty && _navigator?.currentState!=null) {
    final entry=_pending.entries.first;
    final currentContext=_navigator!.currentState!.overlay!.context;
    await showDialog<void>(context:currentContext,barrierDismissible:false,useRootNavigator:true,
     builder:(dialogContext)=>PopScope(canPop:false,child:AlertDialog(
      backgroundColor:const Color(0xFFFFF7F5),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28)),
      icon:const Icon(Icons.front_hand_rounded,color:Color(0xFFD54B48),size:42),
      title:Text('Заказ №${entry.value['preorder_id']} отменён',textAlign:TextAlign.center,
       style:const TextStyle(color:Color(0xFF942E2C),fontWeight:FontWeight.w800)),
      content:const Text('Не готовьте и не выдавайте этот заказ.\n\nЕсли уже начали приготовление, остановитесь и сообщите ответственному сотруднику.',
       textAlign:TextAlign.center,style:TextStyle(fontSize:16,height:1.45)),
      actionsAlignment:MainAxisAlignment.center,
      actions:[FilledButton(onPressed:() async {
       if(_ackInFlight)return;
       _ackInFlight=true;
       try {
        final next={..._acknowledged,entry.key};
        final stored=next.toList();
        if(stored.length>500)stored.removeRange(0,stored.length-500);
        final saved=await _preferences!.setStringList(_ackKey,stored);
        if(!saved)throw StateError('ack save failed');
        _acknowledged..clear()..addAll(stored);
        _pending.remove(entry.key);
        await _savePending();
        if(dialogContext.mounted)Navigator.of(dialogContext).pop();
       } catch (_) {
        if(dialogContext.mounted)ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content:Text('Не удалось сохранить подтверждение. Нажмите «Увидел» ещё раз.')));
       } finally {_ackInFlight=false;}
      },style:FilledButton.styleFrom(backgroundColor:const Color(0xFFD54B48),padding:const EdgeInsets.symmetric(horizontal:40,vertical:16)),
       child:const Text('Увидел',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)))])));
   }
  } finally {_showing=false;}
 }
}
