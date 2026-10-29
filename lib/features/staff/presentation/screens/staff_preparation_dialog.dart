import 'dart:async';
import 'package:flutter/material.dart';

class StaffPreparationChoice {
  final int minutes;
  final bool acceptClientTime;
  const StaffPreparationChoice(this.minutes,{this.acceptClientTime=false});
}

class StaffPreparationDialog extends StatefulWidget {
  final int minimum;
  final DateTime? requested;
  final bool respectRequestedFloor;
  const StaffPreparationDialog({super.key,required this.minimum,this.requested,this.respectRequestedFloor=true});
  @override
  State<StaffPreparationDialog> createState() => _StaffPreparationDialogState();
}
class _StaffPreparationDialogState extends State<StaffPreparationDialog> {
  late final TextEditingController _minutes;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _minutes=TextEditingController(text: '${widget.minimum}');
    _timer=Timer.periodic(const Duration(seconds: 1),(_){if(mounted)setState(() {});});
  }
  @override
  void dispose(){_timer?.cancel();_minutes.dispose();super.dispose();}
  String _time(DateTime d) => '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  @override
  Widget build(BuildContext context) {
    final now=DateTime.now();
    final requested=widget.requested;
    final earliest=now.add(Duration(minutes: widget.minimum));
    final canAccept=requested!=null && !requested.isBefore(earliest);
    final chosen=int.tryParse(_minutes.text.trim());
    final valid=chosen!=null && chosen>=widget.minimum && chosen<=180;
    final base=now.add(Duration(minutes: chosen ?? widget.minimum));
    final expected=widget.respectRequestedFloor && requested!=null && requested.isAfter(base) ? requested : base;
    return AlertDialog(
      backgroundColor: const Color(0xFFF2F8F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: const Text('Когда будет готов?',style: TextStyle(fontSize: 23,fontWeight: FontWeight.w800)),
      content: SizedBox(width: 360,child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,mainAxisSize: MainAxisSize.min,children: [
          if(requested!=null) ...[
            Container(padding: const EdgeInsets.all(15),decoration: BoxDecoration(
              color: Colors.white,borderRadius: BorderRadius.circular(20),border: Border.all(color: const Color(0xFFBDDDE4))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
                const Text('Время клиента',style: TextStyle(fontSize: 15,color: Color(0xFF45616B))),
                const SizedBox(height: 6),
                Text(_time(requested),style: const TextStyle(fontSize: 24,fontWeight: FontWeight.w800,color: Color(0xFF173B52))),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: canAccept ? () => Navigator.pop(context,StaffPreparationChoice(widget.minimum,acceptClientTime: true)) : null,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF246BFF),padding: const EdgeInsets.symmetric(horizontal: 14,vertical: 14)),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Принять время клиента',style: TextStyle(fontSize: 16,fontWeight: FontWeight.w700))),
                if(!canAccept) Padding(padding: const EdgeInsets.only(top: 10),child: Text(
                  requested.isBefore(now) ? 'Время клиента уже прошло. Укажите новое время ниже.' : 'До времени клиента осталось меньше ${widget.minimum} мин. Укажите новое время ниже.',
                  style: const TextStyle(color: Color(0xFF9D4A20),fontSize: 14,height: 1.4))),
              ])),
            const SizedBox(height: 20),
          ],
          const Text('Указать время приготовления',style: TextStyle(fontSize: 17,fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Минимум ${widget.minimum} мин. после принятия.',style: const TextStyle(fontSize: 14,color: Color(0xFF45616B))),
          const SizedBox(height: 12),
          Wrap(spacing: 8,runSpacing: 8,children: [
            for(final m in (<int>{widget.minimum,widget.minimum+10,30,45,60}.where((m)=>m>=widget.minimum && m<=180).toList()..sort()))
              ChoiceChip(label: Text('$m мин.'),selected: chosen==m,onSelected:(_)=>setState(()=>_minutes.text='$m')),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _minutes,keyboardType: TextInputType.number,onChanged:(_)=>setState((){}),
            decoration: InputDecoration(labelText:'Время, минуты',errorText:valid ? null : 'От ${widget.minimum} до 180 минут',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 16),
          const Text('Подтверждённая готовность',style: TextStyle(fontSize:14,color: Color(0xFF45616B))),
          const SizedBox(height: 6),
          Text(_time(expected),style: const TextStyle(fontSize: 23,fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Клиент увидит время в приложении. Для доставки сохраняется подтверждение времени клиентом.',
            style: TextStyle(fontSize: 13,height: 1.4,color: Color(0xFF45616B))),
        ]))),
      actions: [TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Назад')),
        FilledButton(onPressed:valid ? ()=>Navigator.pop(context,StaffPreparationChoice(chosen!)) : null,
          child:const Text('Принять с этим временем'))],
    );
  }
}
