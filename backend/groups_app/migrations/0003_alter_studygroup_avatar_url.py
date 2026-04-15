from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("groups_app", "0002_studygroup_avatar_url_studygroup_category"),
    ]

    operations = [
        migrations.AlterField(
            model_name="studygroup",
            name="avatar_url",
            field=models.TextField(blank=True),
        ),
    ]
