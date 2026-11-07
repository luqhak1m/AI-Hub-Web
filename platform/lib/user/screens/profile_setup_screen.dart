import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();

  final List<Map<String, TextEditingController>> _experiences = [];
  final List<TextEditingController> _skills = [];
  final List<Map<String, TextEditingController>> _education = [];
  final List<Map<String, TextEditingController>> _certifications = [];

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _linkedinCtrl.dispose();
    for (final e in _experiences) {
      for (final ctrl in e.values) { ctrl.dispose(); }
    }
    for (final ctrl in _skills) { ctrl.dispose(); }
    for (final e in _education) {
      for (final ctrl in e.values) { ctrl.dispose(); }
    }
    for (final c in _certifications) {
      for (final ctrl in c.values) { ctrl.dispose(); }
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final data = await ApiService.getProfile();
      _nameCtrl.text = data['name'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _linkedinCtrl.text = data['linkedin'] ?? '';
      for (final e in (data['experiences'] as List)) {
        _addExperienceWithData(e);
      }
      for (final s in (data['skills'] as List)) {
        _skills.add(TextEditingController(text: s['name']));
      }
      for (final e in (data['education'] as List)) {
        _addEducationWithData(e);
      }
      for (final c in (data['certifications'] as List)) {
        _addCertWithData(c);
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load profile: $e');
    }
  }

  void _addExperienceWithData(Map e) {
    _experiences.add({
      'title': TextEditingController(text: e['title'] ?? ''),
      'company': TextEditingController(text: e['company'] ?? ''),
      'start_date': TextEditingController(text: e['start_date'] ?? ''),
      'end_date': TextEditingController(text: e['end_date'] ?? ''),
      'raw_notes': TextEditingController(text: e['raw_notes'] ?? ''),
    });
  }

  void _addEducationWithData(Map e) {
    _education.add({
      'degree': TextEditingController(text: e['degree'] ?? ''),
      'institution': TextEditingController(text: e['institution'] ?? ''),
      'year': TextEditingController(text: e['year'] ?? ''),
    });
  }

  void _addCertWithData(Map c) {
    _certifications.add({
      'name': TextEditingController(text: c['name'] ?? ''),
      'issuer': TextEditingController(text: c['issuer'] ?? ''),
      'year': TextEditingController(text: c['year'] ?? ''),
    });
  }

  Map<String, dynamic> _buildPayload() => {
    'name': _nameCtrl.text.trim(),
    'email': _emailCtrl.text.trim(),
    'phone': _phoneCtrl.text.trim(),
    'linkedin': _linkedinCtrl.text.trim(),
    'experiences': _experiences.map((e) => {
      'title': e['title']!.text.trim(),
      'company': e['company']!.text.trim(),
      'start_date': e['start_date']!.text.trim(),
      'end_date': e['end_date']!.text.trim().isEmpty ? null : e['end_date']!.text.trim(),
      'is_current': e['end_date']!.text.trim().isEmpty,
      'raw_notes': e['raw_notes']!.text.trim(),
    }).toList(),
    'skills': _skills.map((c) => {'name': c.text.trim()}).toList(),
    'education': _education.map((e) => {'degree': e['degree']!.text.trim(), 'institution': e['institution']!.text.trim(), 'year': e['year']!.text.trim()}).toList(),
    'certifications': _certifications.map((c) => {'name': c['name']!.text.trim(), 'issuer': c['issuer']!.text.trim(), 'year': c['year']!.text.trim()}).toList(),
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final payload = _buildPayload();
      if (widget.isEditing) {
        await ApiService.updateProfile(payload);
      } else {
        await ApiService.createProfile(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Setup Profile',
          style: const TextStyle(color: AppTheme.primary),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Personal Info'),
              _field(_nameCtrl, 'Full Name'),
              _field(_emailCtrl, 'Email'),
              _field(_phoneCtrl, 'Phone (optional)', required: false),
              _field(_linkedinCtrl, 'LinkedIn URL (optional)', required: false),
              const SizedBox(height: 20),
              _sectionHeader('Experience'),
              ..._experiences.asMap().entries.map((e) => _experienceCard(e.key, e.value)),
              _addButton('Add Experience', () => setState(() => _addExperienceWithData({}))),
              const SizedBox(height: 20),
              _sectionHeader('Skills'),
              ..._skills.asMap().entries.map((e) => _skillRow(e.key, e.value)),
              _addButton('Add Skill', () => setState(() => _skills.add(TextEditingController()))),
              const SizedBox(height: 20),
              _sectionHeader('Education'),
              ..._education.asMap().entries.map((e) => _educationCard(e.key, e.value)),
              _addButton('Add Education', () => setState(() => _addEducationWithData({}))),
              const SizedBox(height: 20),
              _sectionHeader('Certifications (optional)'),
              ..._certifications.asMap().entries.map((e) => _certCard(e.key, e.value)),
              _addButton('Add Certification', () => setState(() => _addCertWithData({}))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFEF233C))),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: const Color(0xFF888888),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(widget.isEditing ? 'Save Changes' : 'Save & Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w600)),
  );

  Widget _field(TextEditingController ctrl, String label, {bool required = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFEF233C), fontSize: 12),
      ),
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
    ),
  );

  Widget _addButton(String label, VoidCallback onTap) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add, color: AppTheme.primary),
    label: Text(label, style: const TextStyle(color: AppTheme.primary)),
  );

  Widget _skillRow(int index, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: _field(ctrl, 'Skill ${index + 1}')),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF888888)),
        onPressed: () => setState(() => _skills.removeAt(index)),
      ),
    ]),
  );

  Widget _experienceCard(int i, Map<String, TextEditingController> e) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Experience ${i + 1}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF888888), size: 18),
          onPressed: () => setState(() => _experiences.removeAt(i)),
        ),
      ]),
      _field(e['title']!, 'Job Title'),
      _field(e['company']!, 'Company'),
      _field(e['start_date']!, 'Start Date (e.g. Jan 2022)'),
      _field(e['end_date']!, 'End Date (leave blank if current)', required: false),
      _field(e['raw_notes']!, 'Responsibilities & achievements (your own words)'),
    ]),
  );

  Widget _educationCard(int i, Map<String, TextEditingController> e) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Education ${i + 1}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF888888), size: 18),
          onPressed: () => setState(() => _education.removeAt(i)),
        ),
      ]),
      _field(e['degree']!, 'Degree'),
      _field(e['institution']!, 'Institution'),
      _field(e['year']!, 'Graduation Year'),
    ]),
  );

  Widget _certCard(int i, Map<String, TextEditingController> c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Certification ${i + 1}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF888888), size: 18),
          onPressed: () => setState(() => _certifications.removeAt(i)),
        ),
      ]),
      _field(c['name']!, 'Certificate Name'),
      _field(c['issuer']!, 'Issuer'),
      _field(c['year']!, 'Year'),
    ]),
  );
}
