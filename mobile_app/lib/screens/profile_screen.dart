import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUsername;

  const ProfileScreen({super.key, this.targetUsername});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _loaded = false;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: '********');
  final _fullName = TextEditingController();
  final _classCode = TextEditingController();
  final _studentId = TextEditingController();
  final _dob = TextEditingController();
  final _major = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _gender = TextEditingController();

  bool get _isOwnProfile => widget.targetUsername == null;

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
    _phone.dispose();
    _address.dispose();
    _gender.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uri = Uri.parse('${AppApi.users}/profile/').replace(
        queryParameters: _isOwnProfile
            ? {'username': AppSession.username}
            : {'target_username': widget.targetUsername!},
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        _username.text = (data['username'] ?? '').toString();
        _email.text = (data['email'] ?? '').toString();
        _fullName.text = (data['full_name'] ?? '').toString();
        _classCode.text = (data['class_code'] ?? '').toString();
        _studentId.text = (data['student_id'] ?? '').toString();
        _dob.text = (data['date_of_birth'] ?? '').toString();
        _major.text = (data['major'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
        _address.text = (data['address'] ?? '').toString();
        _gender.text = (data['gender'] ?? '').toString();
      } else {
        _showError('Không tải được thông tin tài khoản (${res.statusCode}).');
      }
    } catch (e) {
      _showError('Có lỗi khi tải hồ sơ: $e');
    } finally {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final res = await http.patch(
        Uri.parse(
          '${AppApi.users}/profile/',
        ).replace(queryParameters: {'username': AppSession.username}),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': AppSession.username,
          'full_name': _fullName.text.trim(),
          'class_code': _classCode.text.trim(),
          'student_id': _studentId.text.trim(),
          'date_of_birth': _dob.text.trim(),
          'major': _major.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
          'gender': _gender.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
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
      } else {
        _showError('Cập nhật thất bại (${res.statusCode}).');
      }
    } catch (e) {
      _showError('Có lỗi khi cập nhật hồ sơ: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'Thông tin tài khoản' : 'Hồ sơ người dùng'),
      ),
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
            if (_isOwnProfile) _field(_password, 'Mật khẩu', enabled: false),
            const SizedBox(height: 10),
            _sectionLabel('Thông tin sinh viên'),
            _field(_fullName, 'Họ và tên'),
            _field(_classCode, 'Lớp học'),
            _field(_studentId, 'Mã sinh viên'),
            _field(_dob, 'Ngày sinh'),
            _field(_major, 'Chuyên ngành'),
            _field(_phone, 'Số điện thoại'),
            _field(_gender, 'Giới tính'),
            _field(_address, 'Địa chỉ hiện tại', maxLines: 2),
            const SizedBox(height: 16),
            if (_isOwnProfile)
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
    final canEdit = _isOwnProfile && enabled && _isEditing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: canEdit,
        maxLines: maxLines,
        validator: (value) {
          if (!canEdit) return null;
          if ((value ?? '').trim().isEmpty) {
            return 'Không được để trống';
          }
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
