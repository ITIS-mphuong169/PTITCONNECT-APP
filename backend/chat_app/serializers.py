from users.models import Profile
from users.serializers import ProfileSerializer
from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.username", read_only=True)

    class Meta:
        model = Message
        fields = ["id", "sender_name", "content", "is_read", "created_at"]


class ConversationSerializer(serializers.ModelSerializer):
    peer_profile = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    matched_message = serializers.SerializerMethodField()
    matched_count = serializers.SerializerMethodField()
    last_message_time = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id",
            "peer_profile",
            "last_message",
            "matched_message",
            "matched_count",
            "unread_count",
            "created_at",
            "updated_at",
            "last_message_time",
        ]

    def _peer(self, obj):
        user = self.context.get("user")
        if not user:
            return obj.user2
        return obj.user2 if obj.user1_id == user.id else obj.user1

    def get_peer_profile(self, obj):
        peer = self._peer(obj)
        profile, _ = Profile.objects.get_or_create(user=peer)
        return ProfileSerializer(profile).data

    def get_last_message(self, obj):
        last = obj.messages.order_by("-created_at").first()
        if not last:
            return ""
        return last.content[:200] if last.content else ""

    def get_matched_message(self, obj):
        query = (self.context.get("search_query") or "").strip()
        if not query:
            return ""
        msg = obj.messages.filter(content__icontains=query).order_by("-created_at").first()
        if not msg or not msg.content:
            return ""
        return msg.content[:200]

    def get_last_message_time(self, obj):
        last = obj.messages.order_by("-created_at").first()
        return getattr(last, "created_at", None)

    def get_matched_count(self, obj):
        query = (self.context.get("search_query") or "").strip()
        if not query:
            return 0
        return obj.messages.filter(content__icontains=query).count()

    def get_unread_count(self, obj):
        user = self.context.get("user")
        if not user:
            return 0
        return obj.messages.exclude(sender=user).filter(is_read=False).count()
