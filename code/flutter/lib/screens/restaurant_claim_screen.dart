import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Restaurant Claim flow — see docs/13-RESTAURANT-CLAIM.md §6.
/// 6 screens: Intro → Position → Contact + OTP → License → Geo Visit → Done.
class RestaurantClaimScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String coverImage;
  final Future<String> Function(Map<String, dynamic>) onStart; // returns claimId
  final Future<void> Function(String claimId, String otp) onVerifyOtp;
  final Future<void> Function(String claimId, String licenseUrl) onUploadLicense;
  final Future<void> Function(String claimId, double lat, double lng) onVerifyGeo;

  const RestaurantClaimScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.coverImage,
    required this.onStart,
    required this.onVerifyOtp,
    required this.onUploadLicense,
    required this.onVerifyGeo,
  });

  @override
  State<RestaurantClaimScreen> createState() => _RestaurantClaimScreenState();
}

class _RestaurantClaimScreenState extends State<RestaurantClaimScreen> {
  final _ctrl = PageController();
  int _idx = 0;
  String? _claimId;
  String _position = 'owner';
  String _phone = '';
  String _email = '';
  String _otp = '';
  bool _busy = false;
  double _verifyScore = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Xác nhận quán'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          _progressIndicator(),
          Expanded(
            child: PageView(
              controller: _ctrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _intro(),
                _positionStep(),
                _contactStep(),
                _otpStep(),
                _licenseStep(),
                _geoStep(),
                _doneStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.x4, 0, AppSpacing.x4, AppSpacing.x3),
      child: Row(
        children: List.generate(7, (i) {
          final active = i <= _idx;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == 6 ? 0 : 4),
              decoration: BoxDecoration(
                color: active ? AppColors.phoOrange : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _goto(int i) {
    setState(() => _idx = i);
    _ctrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic);
  }

  // ---- Steps ----

  Widget _intro() => _StepWrap(
        title: 'Là chủ / quản lý quán này?',
        subtitle: widget.restaurantName,
        image: widget.coverImage,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Bullet('Cập nhật menu real-time'),
            _Bullet('Nhận đặt giao trực tiếp'),
            _Bullet('Phản hồi review'),
            _Bullet('Quảng cáo & analytics'),
          ],
        ),
        primary: 'Bắt đầu xác nhận',
        onPrimary: () => _goto(1),
        secondary: 'Tôi không phải chủ',
        onSecondary: () => Navigator.maybePop(context),
      );

  Widget _positionStep() => _StepWrap(
        title: 'Vị trí của bạn?',
        subtitle: 'Để chúng tôi biết bạn có thẩm quyền',
        body: Column(
          children: [
            _RadioRow(label: 'Chủ quán',                value: 'owner',     groupValue: _position, onChanged: (v) => setState(() => _position = v)),
            _RadioRow(label: 'Quản lý',                 value: 'manager',   groupValue: _position, onChanged: (v) => setState(() => _position = v)),
            _RadioRow(label: 'Nhân viên / Marketing',   value: 'staff',     groupValue: _position, onChanged: (v) => setState(() => _position = v)),
          ],
        ),
        primary: 'Tiếp tục',
        onPrimary: () => _goto(2),
      );

  Widget _contactStep() => _StepWrap(
        title: 'Số liên hệ',
        subtitle: 'Chúng tôi gửi OTP đến số điện thoại quán',
        body: Column(
          children: [
            TextField(
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại quán', prefixIcon: Icon(Icons.phone)),
              onChanged: (v) => _phone = v.trim(),
            ),
            const SizedBox(height: AppSpacing.x3),
            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (tuỳ chọn)', prefixIcon: Icon(Icons.email_outlined)),
              onChanged: (v) => _email = v.trim(),
            ),
          ],
        ),
        primary: _busy ? 'Đang gửi...' : 'Gửi OTP',
        onPrimary: _phone.isEmpty || _busy ? null : _startClaimAndSendOtp,
      );

  Widget _otpStep() => _StepWrap(
        title: 'Nhập mã OTP',
        subtitle: 'Đã gửi đến số $_phone',
        body: TextField(
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppTypography.displayLg,
          decoration: const InputDecoration(counterText: ''),
          onChanged: (v) => _otp = v.trim(),
        ),
        primary: _busy ? 'Đang xác nhận...' : 'Xác nhận',
        onPrimary: _otp.length == 6 && !_busy ? _verifyOtp : null,
      );

  Widget _licenseStep() => _StepWrap(
        title: 'Giấy phép kinh doanh',
        subtitle: '(Khuyến nghị, để được duyệt nhanh)',
        body: Column(
          children: [
            const Text(
              'Upload ảnh ĐKKD / Hộ kinh doanh.\nChúng tôi xoá sau khi xác nhận xong.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.x5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UploadButton(icon: Icons.photo_camera_outlined, label: 'Chụp ảnh', onTap: _uploadLicense),
                const SizedBox(width: AppSpacing.x3),
                _UploadButton(icon: Icons.photo_library_outlined, label: 'Thư viện', onTap: _uploadLicense),
              ],
            ),
          ],
        ),
        primary: 'Tiếp tục',
        onPrimary: () => _goto(5),
        secondary: 'Bỏ qua bước này',
        onSecondary: () => _goto(5),
      );

  Widget _geoStep() => _StepWrap(
        title: 'Đang ở quán?',
        subtitle: 'Để chúng tôi xác nhận GPS (≤50m)',
        body: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Icon(Icons.place, size: 96, color: AppColors.phoOrange),
        ),
        primary: 'Tôi đang ở đây',
        onPrimary: _verifyGeo,
        secondary: 'Bỏ qua bước này',
        onSecondary: () => _goto(6),
      );

  Widget _doneStep() {
    final approved = _verifyScore >= 0.7;
    return _StepWrap(
      title: approved ? '🎉 Xác nhận thành công!' : '✅ Yêu cầu đã gửi',
      subtitle: approved
          ? 'Quán của bạn đã được verify ✓'
          : 'Đội ngũ HNAG sẽ xem xét trong 24h.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (approved) ...[
            _Bullet('Truy cập Dashboard quản lý'),
            _Bullet('Tự động import menu từ data hiện có'),
            _Bullet('Mời nhân viên cộng tác'),
          ] else
            _Bullet('Chúng tôi sẽ thông báo qua app khi duyệt xong'),
        ],
      ),
      primary: approved ? 'Mở Dashboard' : 'Hoàn thành',
      onPrimary: () => Navigator.pop(context, { 'approved': approved }),
    );
  }

  // ---- Actions ----

  Future<void> _startClaimAndSendOtp() async {
    setState(() => _busy = true);
    try {
      _claimId = await widget.onStart({
        'position': _position,
        'contactPhone': _phone,
        'contactEmail': _email,
      });
      _goto(3);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_claimId == null) return;
    setState(() => _busy = true);
    try {
      await widget.onVerifyOtp(_claimId!, _otp);
      _verifyScore += 0.6;
      _goto(4);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP không đúng')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadLicense() async {
    if (_claimId == null) return;
    // In production: file_picker + upload to S3, then call onUploadLicense
    await widget.onUploadLicense(_claimId!, 'https://cdn.tothanhthuy.cloud/license/stub.jpg');
    _verifyScore += 0.4;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tải lên'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _verifyGeo() async {
    if (_claimId == null) return;
    setState(() => _busy = true);
    try {
      // In production: geolocator.getCurrentPosition()
      await widget.onVerifyGeo(_claimId!, 10.7740, 106.6940);
      _verifyScore += 0.3;
      _goto(6);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xác nhận được: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Building blocks

class _StepWrap extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? image;
  final Widget body;
  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  const _StepWrap({
    required this.title,
    this.subtitle,
    this.image,
    required this.body,
    required this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null) ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: image!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFEDEDED)),
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ),
          ),
          if (image != null) const SizedBox(height: AppSpacing.x4),
          Text(title, style: AppTypography.headingMd),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(subtitle!, style: AppTypography.bodyMd.copyWith(color: Colors.grey.shade600)),
          ],
          const SizedBox(height: AppSpacing.x5),
          body,
          const SizedBox(height: AppSpacing.x6),
          ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.phoOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.full)),
            ),
            child: Text(primary, style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.x2),
            TextButton(onPressed: onSecondary, child: Text(secondary!)),
          ],
          const SizedBox(height: AppSpacing.x6),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;
  const _RadioRow({required this.label, required this.value, required this.groupValue, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Radio<String>(value: value, groupValue: groupValue, onChanged: (v) { if (v != null) onChanged(v); }),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.bodyLg),
          ],
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _UploadButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          color: AppColors.phoOrange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.phoOrange.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.phoOrange),
            const SizedBox(height: 8),
            Text(label, style: AppTypography.caption.copyWith(color: AppColors.phoOrange)),
          ],
        ),
      ),
    );
  }
}
