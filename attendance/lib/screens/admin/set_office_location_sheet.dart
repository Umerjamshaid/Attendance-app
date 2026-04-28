import 'package:flutter/material.dart';
import '../../config/wc_tokens.dart';

class SetOfficeLocationSheet extends StatefulWidget {
  const SetOfficeLocationSheet({super.key});

  @override
  State<SetOfficeLocationSheet> createState() => _SetOfficeLocationSheetState();
}

class _SetOfficeLocationSheetState extends State<SetOfficeLocationSheet> {
  final _nameCtrl = TextEditingController(text: 'Osquare');
  final _latCtrl = TextEditingController(text: '24');
  final _lngCtrl = TextEditingController(text: '67');
  final _radiusCtrl = TextEditingController(text: '100');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: WC.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: WC.rFull,
              ),
            ),
          ),
          const Text(
            'Set Office Location',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: WC.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anyone within the radius will be marked "Present".',
            style: TextStyle(fontSize: 13, color: WC.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          _UseLocationButton(),
          const SizedBox(height: 20),
          _FieldLabel(text: 'OFFICE NAME'),
          const SizedBox(height: 8),
          _LocationField(controller: _nameCtrl, hint: 'e.g. Headquarters'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(text: 'LATITUDE'),
                    const SizedBox(height: 8),
                    _LocationField(
                      controller: _latCtrl,
                      hint: '0.0000',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(text: 'LONGITUDE'),
                    const SizedBox(height: 8),
                    _LocationField(
                      controller: _lngCtrl,
                      hint: '0.0000',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel(text: 'RADIUS (METERS)'),
          const SizedBox(height: 8),
          _LocationField(
            controller: _radiusCtrl,
            hint: '100',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 6),
          const Text(
            'Suggested: 50–500 m for buildings, 1000+ m for campuses.',
            style: TextStyle(fontSize: 11, color: WC.muted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: WC.surface,
                      borderRadius: WC.rFull,
                      border: Border.all(color: WC.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: WC.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: WC.black,
                      borderRadius: WC.rFull,
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: WC.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  color: WC.white,
                                  size: 18,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Save Location',
                                  style: TextStyle(
                                    color: WC.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UseLocationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: WC.bg,
          borderRadius: WC.rFull,
          border: Border.all(color: WC.border, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.my_location_rounded, size: 18, color: WC.black),
            SizedBox(width: 10),
            Text(
              'Use My Current Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: WC.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: WC.muted,
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _LocationField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: WC.bg,
        borderRadius: WC.r12,
        border: Border.all(color: WC.border, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: WC.black,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: WC.muted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}
