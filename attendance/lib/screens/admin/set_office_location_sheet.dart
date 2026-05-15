import 'package:attendance/services/local_storage_service.dart';
import 'package:attendance/services/office_service.dart';
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
  bool _isLocating = false; // Track if GPS is searching

  final _storageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  // ✅ Load saved location on startup
  Future<void> _loadSavedLocation() async {
    final saved = await _storageService.getOfficeLocation();
    if (saved != null) {
      _nameCtrl.text = saved['name'];
      _latCtrl.text = saved['latitude'].toString();
      _lngCtrl.text = saved['longitude'].toString();
      _radiusCtrl.text = saved['radius'].toString();
    }
  }

  // ✅ Save location to SharedPreferences
  Future<void> _saveLocation() async {
    setState(() => _saving = true);

    try {
      await _storageService.saveOfficeLocation(
        name: _nameCtrl.text,
        latitude: double.parse(_latCtrl.text),
        longitude: double.parse(_lngCtrl.text),
        radius: int.parse(_radiusCtrl.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Office location saved!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  //Get the Button
  void _getCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final officeService = OfficeService();
      final position = await officeService.determineCurrentPosition();
      final isInOffice = await officeService.isUserInOffice(position);

      // Logic: Update controllers here
      // text field filling
      _latCtrl.text = position.latitude.toString();
      _lngCtrl.text = position.longitude.toString();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location Captured')));
    } catch (e) {
      // Logic: Show a message to the user!
      // In Flutter, you can use:
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLocating = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
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
          _UseLocationButton(
            isLoading: _isLocating,
            onTap: _getCurrentLocation, // ← Pass your function here!
          ),
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
                  onTap: _saving ? null : _saveLocation,
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
  // 1. Define the callback 'onLocationFound'
  final VoidCallback onTap;
  final bool isLoading;

  const _UseLocationButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      // Added Material for InkWell support
      color: Colors.transparent,
      // Changed GestureDetector to InkWell for ripple effect
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: WC.rFull,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: WC.rFull,
            border: Border.all(color: WC.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: WC.black,
                ),
              const SizedBox(width: 10),
              const Text('Use My Current Location'),
            ],
          ),
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
