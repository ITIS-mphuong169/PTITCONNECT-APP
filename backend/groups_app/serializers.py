from rest_framework import serializers

from .models import GroupMember, JoinRequest, StudyGroup


class StudyGroupSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source="owner.username", read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = StudyGroup
        fields = [
            "id",
            "owner_name",
            "title",
            "subject",
            "description",
            "max_members",
            "created_at",
            "member_count",
        ]
        read_only_fields = ["id", "owner_name", "created_at", "member_count"]

    def get_member_count(self, obj):
        return obj.memberships.count()


class JoinRequestSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = JoinRequest
        fields = ["id", "group", "user_name", "status", "created_at"]
