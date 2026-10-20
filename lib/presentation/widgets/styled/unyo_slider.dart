import 'package:flutter/material.dart';

class UnyoSlider extends StatefulWidget {
  final int minValue;
  final int maxValue;
  final num initialValue;
  final int? divisions;
  final String title;
  final void Function(double) onChanged;

  const UnyoSlider({
    super.key,
    required this.minValue,
    required this.initialValue,
    required this.maxValue,
    required this.title,
    required this.onChanged,
    this.divisions,
  });

  @override
  State<UnyoSlider> createState() => _UnyoSliderState();
}

class _UnyoSliderState extends State<UnyoSlider> {
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const SizedBox(width: 10),
            SizedBox(
              width: 35,
              child: Text(
                _currentValue == _currentValue.roundToDouble()
                    ? _currentValue.toInt().toString()
                    : _currentValue.toStringAsFixed(1),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Expanded(
              child: Slider(
                value: _currentValue,
                min: widget.minValue.toDouble(),
                max: widget.maxValue.toDouble(),
                divisions: widget.divisions ??
                    ((widget.maxValue - widget.minValue) == 0 ? null : widget.maxValue - widget.minValue),
                // label: "$_currentValue",
                activeColor: ColorScheme.of(context).tertiary,
                inactiveColor: ColorScheme.of(context).secondary.withValues(alpha: 0.4),
                onChanged: (value) {
                  setState(() {
                    _currentValue = double.parse(value.toStringAsFixed(1));
                  });
                  widget.onChanged(_currentValue);
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.maxValue.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ],
    );
  }
}
