import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _storageKey = 'mock_profile_v1';

  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _loaded = false;

  final _username = TextEditingController(text: 'phuongmgt');
  final _email = TextEditingController(text: 'phuongmgt@stu.ptit.edu.vn');
  final _password = TextEditingController(text: '********');
  final _fullName = TextEditingController(text: 'Mai Phuong');
  final _classCode = TextEditingController(text: 'N4');
  final _studentId = TextEditingController(text: 'B22DCCN123');
  final _dob = TextEditingController(text: '01/09/2004');
  final _major = TextEditingController(text: 'D22CNPM03');
  final _cccd = TextEditingController(text: '0123456789');
  final _address = TextEditingController(text: 'T2S, Mo Lao, Ha Dong');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _classCode.dispose();
    _studentId.dispose();
    _dob.dispose();
    _major.dispose();
    _cccd.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _fullName.text = (data['fullName'] ?? _fullName.text).toString();
      _classCode.text = (data['classCode'] ?? _classCode.text).toString();
      _studentId.text = (data['studentId'] ?? _studentId.text).toString();
      _dob.text = (data['dob'] ?? _dob.text).toString();
      _major.text = (data['major'] ?? _major.text).toString();
      _cccd.text = (data['cccd'] ?? _cccd.text).toString();
      _address.text = (data['address'] ?? _address.text).toString();
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'fullName': _fullName.text.trim(),
        'classCode': _classCode.text.trim(),
        'studentId': _studentId.text.trim(),
        'dob': _dob.text.trim(),
        'major': _major.text.trim(),
        'cccd': _cccd.text.trim(),
        'address': _address.text.trim(),
      }),
    );
    if (!mounted) return;
    setState(() => _isEditing = false);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thành công'),
        content: const Text('Cập nhật thông tin thành công'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin tài khoản')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFF8D5E0),
                child: Icon(Icons.person, size: 34),
              ),
            ),
            const SizedBox(height: 18),
            _sectionLabel('Tài khoản'),
            _field(_username, 'Username', enabled: false),
            _field(_email, 'Email edu', enabled: false),
            _field(_password, 'Mật khẩu', enabled: false),
            const SizedBox(height: 10),
            _sectionLabel('Thông tin sinh viên'),
            _field(_fullName, 'Họ và tên'),
            _field(_classCode, 'Lớp học'),
            _field(_studentId, 'Mã sinh viên'),
            _field(_dob, 'Ngày sinh'),
            _field(_major, 'Mã lớp'),
            _field(_cccd, 'Số căn cước'),
            _field(_address, 'Địa chỉ hiện tại', maxLines: 2),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isEditing
                  ? _saveProfile
                  : () => setState(() => _isEditing = true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFFF33B6D),
                foregroundColor: Colors.white,
              ),
              child: Text(_isEditing ? 'Lưu' : 'Chỉnh sửa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    int maxLines = 1,
  }) {
    final canEdit = enabled && _isEditing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: canEdit,
        maxLines: maxLines,
        validator: (value) {
          if (!canEdit) return null;
          if ((value ?? '').trim().isEmpty) return 'Không được để trống';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: canEdit ? Colors.white : const Color(0xFFF7F7F7),
        ),
      ),
    );
  }
}
