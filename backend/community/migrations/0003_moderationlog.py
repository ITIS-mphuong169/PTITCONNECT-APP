import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("community", "0002_comment_parent_post_file_post_image"),
    ]

    operations = [
        migrations.CreateModel(
            name="ModerationLog",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "target_type",
                    models.CharField(
                        choices=[
                            ("USER", "Người dùng"),
                            ("POST", "Bài viết"),
                        ],
                        max_length=10,
                    ),
                ),
                (
                    "violation_type",
                    models.CharField(max_length=100),
                ),
                ("reason", models.TextField()),
                (
                    "violating_content",
                    models.TextField(blank=True, null=True),
                ),
                ("risk_score", models.IntegerField(default=0)),
                ("is_auto_flagged", models.BooleanField(default=False)),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("PENDING", "Đang chờ xử lý"),
                            ("BANNED", "Đã khóa/Xóa"),
                            ("IGNORED", "Bỏ qua"),
                        ],
                        default="PENDING",
                        max_length=20,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "target_post",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="moderation_logs",
                        to="community.post",
                    ),
                ),
                (
                    "target_user",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="moderation_logs",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
        ),
    ]
