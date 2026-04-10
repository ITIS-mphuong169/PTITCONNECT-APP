from django.contrib.auth.models import User
from rest_framework import serializers

from .models import FriendRequest, Profile


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["username", "email", "password"]

    def create(self, validated_data):
        return User.objects.create_user(
            username=validated_data["username"],
            email=validated_data.get("email", ""),
            password=validated_data["password"],
        )


class ProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = Profile
        fields = [
            "id",
            "username",
            "email",
            "full_name",
            "student_id",
            "class_code",
            "phone",
            "gender",
            "date_of_birth",
            "address",
            "major",
            "bio",
            "avatar",
        ]


class FriendRequestSerializer(serializers.ModelSerializer):
    from_username = serializers.CharField(source="from_user.username", read_only=True)
    to_username = serializers.CharField(source="to_user.username", read_only=True)

    class Meta:
        model = FriendRequest
        fields = ["id", "from_username", "to_username", "status", "created_at"]
