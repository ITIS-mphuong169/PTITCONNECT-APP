from rest_framework import serializers

from .models import Comment, Post


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.username", read_only=True)

    class Meta:
        model = Comment
        fields = ["id", "author_name", "content", "created_at"]


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.username", read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    like_count = serializers.SerializerMethodField()
    save_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = [
            "id",
            "author_name",
            "title",
            "content",
            "topic",
            "created_at",
            "like_count",
            "save_count",
            "comment_count",
            "comments",
        ]

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_save_count(self, obj):
        return obj.saved_by.count()

    def get_comment_count(self, obj):
        return obj.comments.count()
