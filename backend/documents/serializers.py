from rest_framework import serializers

from .models import Document


class DocumentSerializer(serializers.ModelSerializer):
    uploader_name = serializers.CharField(source="uploader.username", read_only=True)
    file_url = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Document
        fields = [
            "id",
            "uploader_name",
            "title",
            "subject",
            "category",
            "document_type",
            "description",
            "download_count",
            "view_count",
            "like_count",
            "is_liked",
            "file",
            "file_url",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "uploader_name",
            "file_url",
            "like_count",
            "is_liked",
            "created_at",
        ]

    def get_file_url(self, obj):
        if not obj.file:
            return None
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.file.url)
        return obj.file.url

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_is_liked(self, obj):
        user = self.context.get("user")
        if not user or not getattr(user, "is_authenticated", False):
            return False
        return obj.likes.filter(user_id=user.id).exists()
