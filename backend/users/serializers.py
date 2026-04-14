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
    from_profile = serializers.SerializerMethodField()
    to_profile = serializers.SerializerMethodField()

    class Meta:
        model = FriendRequest
        fields = [
            "id",
            "from_username",
            "to_username",
            "from_profile",
            "to_profile",
            "status",
            "created_at",
        ]

    def _profile_data(self, user):
        profile, _ = Profile.objects.get_or_create(user=user)
        return ProfileSerializer(profile).data

    def get_from_profile(self, obj):
        return self._profile_data(obj.from_user)

    def get_to_profile(self, obj):
        return self._profile_data(obj.to_user)
