import 'package:flutter/material.dart';
import '../../data/staff_client_qr_api.dart';

class StaffRafflePrizeScreen extends StatefulWidget {
 final int establishmentId;final String qr;
 const StaffRafflePrizeScreen({super.key,required this.establishmentId,required this.qr});
 @override State<StaffRafflePrizeScreen> createState()=>_StaffRafflePrizeScreenState();
}
class _StaffRafflePrizeScreenState extends State<StaffRafflePrizeScreen> {
 Map<String,dynamic>? _prize;String? _error;bool _busy=false;
 @override void initState(){super.initState();_load(false);}
 Future<void> _load(bool redeem) async {
  if(_busy)return;setState((){_busy=true;_error=null;});
  try {
   final result=await StaffClientQrApi().rafflePrize(establishmentId:widget.establishmentId,qr:widget.qr,redeem:redeem);
   if(mounted)setState(()=>_prize=redeem?{...?_prize,...result}:result);
  } catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 Future<void> _confirm() async {
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Выдать приз?'),content:Text('${_prize?['prize_text'] ?? ''}\nПобедитель: ${_prize?['winner_name'] ?? ''}'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Назад')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Подтвердить выдачу'))]));
  if(ok==true && mounted)await _load(true);
 }
 @override Widget build(BuildContext context) {
  final state='${_prize?['state'] ?? ''}';
  return Scaffold(backgroundColor:const Color(0xFFF3F8F9),appBar:AppBar(title:const Text('Приз розыгрыша')),body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   if(_prize!=null)Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFDBF4EC),Color(0xFFE6DCFA)]),borderRadius:BorderRadius.circular(28)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${_prize!['establishment_name'] ?? ''}',style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:24),Text('${_prize!['prize_text'] ?? ''}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:18),Text('Победитель: ${_prize!['winner_name'] ?? ''}',style:const TextStyle(fontSize:17)),const SizedBox(height:12),Text(state=='redeemed'?'Приз уже выдан':state=='expired'?'Срок получения приза истёк':'Можно выдать',style:TextStyle(color:state=='available'?const Color(0xFF267A64):const Color(0xFF825970),fontWeight:FontWeight.w800)),if('${_prize!['expires_at'] ?? ''}'.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text('Получить до: ${DateTime.tryParse('${_prize!['expires_at']}')?.toLocal() ?? _prize!['expires_at']}'))])),
   if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:20),child:Text(_error!,style:const TextStyle(color:Colors.red))),
   const SizedBox(height:24),if(_busy)const Center(child:CircularProgressIndicator()) else if(state=='available')FilledButton(onPressed:_confirm,child:const Padding(padding:EdgeInsets.all(16),child:Text('Выдать приз'))) else if(_error!=null)OutlinedButton(onPressed:()=>_load(false),child:const Text('Проверить снова')),
  ]))));
 }
}
