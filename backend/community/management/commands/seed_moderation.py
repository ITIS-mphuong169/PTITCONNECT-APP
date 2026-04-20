import random
from datetime import timedelta

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.utils import timezone

from community.models import ModerationLog, Post


class Command(BaseCommand):
    help = "Tạo dữ liệu vi phạm cho hệ thống Risk Scoring của Admin"

    def handle(self, *args, **kwargs):
        self.stdout.write("Đang dọn dẹp log kiểm duyệt cũ...")
        ModerationLog.objects.all().delete()

        users = list(User.objects.filter(is_superuser=False, is_staff=False))
        posts = list(Post.objects.all())

        if not users or not posts:
            self.stdout.write(
                self.style.ERROR(
                    "Lỗi: Không có User hoặc Post. Hãy chạy python manage.py seed_full_data trước!"
                )
            )
            return

        self.stdout.write("Đang bơm dữ liệu vi phạm cho Người dùng...")
        user_violations = [
            (
                "Ngôn từ thô tục",
                "Hệ thống Regex phát hiện từ khóa cấm trong nhóm chat.",
                "Thằng ngu này code cái kiểu gì vậy hả...",
            ),
            (
                "Spam link",
                "Nhiều người dùng báo cáo spam link quảng cáo rác.",
                "Click ngay link này để nhận 100k...",
            ),
            (
                "Không phù hợp",
                "Avatar bị report chứa nội dung nhạy cảm.",
                "[Image Flagged]",
            ),
            (
                "Quấy rối",
                "Phát hiện hành vi gửi tin nhắn liên tục (Rate Limit Exceeded).",
                "Spam 20 tin nhắn trong 1 phút.",
            ),
        ]

        flagged_users = random.sample(users, min(15, len(users)))
        for u in flagged_users:
            v_type, reason, content = random.choice(user_violations)
            is_auto = random.choice([True, False])

            score = 30 if is_auto else 0
            score += random.randint(1, 4) * 15

            ModerationLog.objects.create(
                target_type="USER",
                target_user=u,
                violation_type=v_type,
                reason=reason,
                violating_content=content,
                risk_score=score,
                is_auto_flagged=is_auto,
                status="BANNED" if score >= 80 else "PENDING",
                created_at=timezone.now() - timedelta(hours=random.randint(1, 48)),
            )

        self.stdout.write("Đang bơm dữ liệu vi phạm cho Bài viết...")
        post_violations = [
            (
                "Ngôn từ thô tục",
                "Regex phát hiện từ chửi thề trong tiêu đề.",
                "Đm cái môn học này chán vãi...",
            ),
            (
                "Spam/Quảng cáo",
                "Bị report đăng bài quảng cáo cày thuê.",
                "Chuyên nhận cày thuê rank, bán acc...",
            ),
            (
                "Nội dung rác",
                "Spam ký tự vô nghĩa.",
                "test test test test test",
            ),
        ]

        flagged_posts = random.sample(posts, min(20, len(posts)))
        for p in flagged_posts:
            v_type, reason, content = random.choice(post_violations)
            is_auto = random.choice([True, False])
            score = 30 if is_auto else 0
            score += random.randint(1, 5) * 15

            ModerationLog.objects.create(
                target_type="POST",
                target_post=p,
                violation_type=v_type,
                reason=reason,
                violating_content=content,
                risk_score=score,
                is_auto_flagged=is_auto,
                status="BANNED" if score >= 80 else "PENDING",
                created_at=timezone.now() - timedelta(hours=random.randint(1, 24)),
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"Đã tạo thành công {ModerationLog.objects.count()} bản ghi vi phạm (Risk Score) vào Database!"
            )
        )
