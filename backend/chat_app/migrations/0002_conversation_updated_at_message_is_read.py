from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("chat_app", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="conversation",
            name="updated_at",
            field=models.DateTimeField(auto_now=True, null=True),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="message",
            name="is_read",
            field=models.BooleanField(default=False),
        ),
    ]
