import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MpinInputWidget extends StatefulWidget {
  final Function(String) onComplete;
  final Function(String) onChanged;
  final bool obscureText;

  const MpinInputWidget({
    super.key, 
    required this.onComplete, 
    required this.onChanged,
    this.obscureText = true,
  });

  @override
  State<MpinInputWidget> createState() => _MpinInputWidgetState();
}

class _MpinInputWidgetState extends State<MpinInputWidget> {
  List<String> mpinDigits = ["", "", "", ""];
  int currentIndex = 0;
  final TextEditingController _mpinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _mpinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      for (int i = 0; i < 4; i++) {
        mpinDigits[i] = i < value.length ? value[i] : "";
      }
      currentIndex = value.length;
    });
    
    widget.onChanged(value);

    if (value.length == 4) {
      _focusNode.unfocus();
      widget.onComplete(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: TextField(
            controller: _mpinController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            autofocus: true,
            showCursor: false,
            style: const TextStyle(color: Colors.transparent),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
            ),
            onChanged: _onTextChanged,
          ),
        ),
        IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              bool isFocused = index == currentIndex;
              bool hasValue = mpinDigits[index].isNotEmpty;
              return Container(
                width: 50,
                height: 60,
                decoration: BoxDecoration(
                  color: hasValue ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused
                        ? const Color(0xFFF27F0D)
                        : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    hasValue ? (widget.obscureText ? "●" : mpinDigits[index]) : "",
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
