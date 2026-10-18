import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const loyaltyInk = Color(0xFF233D49);
const loyaltyMint = Color(0xFF087F83);

class LoyaltyPage extends StatelessWidget {
 final String title, subtitle;
 final List<Widget> children;
 const LoyaltyPage({super.key, required this.title, required this.subtitle, required this.children});
 @override Widget build(BuildContext context) => Scaffold(
  backgroundColor: const Color(0xFFF4F8F7),
  appBar: AppBar(backgroundColor: const Color(0xFFF4F8F7), foregroundColor: loyaltyInk, elevation: 0,
   title: const Text('FLOWRU', style: TextStyle(fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w800))),
  body: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,
   colors: [Color(0xFFF4F8F7),Color(0xFFE8F5F3),Color(0xFFF2EFFA)])),
   child: SafeArea(top:false,child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:600),
    child: ListView(padding: const EdgeInsets.fromLTRB(24,16,24,32),children:[
     Text(title,style: const TextStyle(color:loyaltyInk,fontSize:32,fontWeight:FontWeight.w800,letterSpacing:-1)),
     const SizedBox(height:8),Text(subtitle,style: const TextStyle(color:Color(0xFF607680),fontSize:15,height:1.45)),
     const SizedBox(height:28),...children]))))));
}
Widget loyaltyField({required TextEditingController controller,required String label,String? hint,bool integer=false,ValueChanged<String>? onSubmitted,bool enabled=true}) => TextField(
 controller:controller,enabled:enabled,keyboardType: integer ? TextInputType.number : const TextInputType.numberWithOptions(decimal:true),
 inputFormatters:integer ? [FilteringTextInputFormatter.digitsOnly] : null,onSubmitted:onSubmitted,
 style:const TextStyle(fontSize:24,fontWeight:FontWeight.w700,color:loyaltyInk),
 decoration:InputDecoration(labelText:label,hintText:hint,filled:true,fillColor:const Color(0x55FFFFFF),
  contentPadding:const EdgeInsets.all(18),border:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:const BorderSide(color:Color(0xFFD3E3E3))),
  focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:const BorderSide(color:loyaltyMint,width:2))));
Widget loyaltyButton(String label,VoidCallback? onTap,{bool busy=false}) => Padding(padding:const EdgeInsets.only(top:20),child:SizedBox(width:double.infinity,
 child:FilledButton(onPressed:onTap,style:FilledButton.styleFrom(backgroundColor:loyaltyMint,disabledBackgroundColor:const Color(0xFFD1DEDF),
 padding:const EdgeInsets.symmetric(horizontal:20,vertical:19),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20))),
 child:busy ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : Text(label,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)))));
Widget loyaltyMetric(String label,String value,{bool prominent=false}) => Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
 Expanded(child:Text(label,style:const TextStyle(color:Color(0xFF607680),fontSize:15))),const SizedBox(width:12),
 Flexible(child:AnimatedSwitcher(duration:const Duration(milliseconds:220),child:Text(value,key:ValueKey(value),textAlign:TextAlign.end,
 style:TextStyle(color:loyaltyInk,fontSize:prominent?30:19,fontWeight:FontWeight.w800))))]));
Widget loyaltyNotice(String text) => Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text(text,style:const TextStyle(color:Color(0xFFB14240),fontSize:14,height:1.4)));
