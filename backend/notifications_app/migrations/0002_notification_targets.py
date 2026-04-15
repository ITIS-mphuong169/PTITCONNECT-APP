from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("notifications_app", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="notification",
            name="conversation_id",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="notification",
            name="group_id",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="notification",
            name="notification_type",
            field=models.CharField(
                choices=[
                    ("message", "Message"),
                    ("friend_request", "Friend Request"),
                    ("friend_accept", "Friend Accept"),
                    ("post_like", "Post Like"),
                    ("post_comment", "Post Comment"),
                    ("group", "Group"),
                    ("system", "System"),
                ],
                default="system",
                max_length=30,
            ),
        ),
        migrations.AddField(
            model_name="notification",
            name="post_id",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="notification",
            name="target_username",
            field=models.CharField(blank=True, default="", max_length=150),
            preserve_default=False,
        ),
    ]
