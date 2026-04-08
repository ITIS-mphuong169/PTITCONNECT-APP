from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.username", read_only=True)

    class Meta:
        model = Message
        fields = ["id", "sender_name", "content", "created_at"]


class ConversationSerializer(serializers.ModelSerializer):
    peer_username = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ["id", "peer_username", "last_message", "created_at"]

    def get_peer_username(self, obj):
        request = self.context.get("request")
        user = self.context.get("user")
        if not user:
            return None
        if obj.user1_id == user.id:
            return obj.user2.username
        return obj.user1.username

    def get_last_message(self, obj):
        last = obj.messages.last()
        if not last:
            return ""
        return last.content[:200] if last.content else ""
