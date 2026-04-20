from django.contrib.auth.models import User
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

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


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = "email"
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    class Meta:
        fields = ["email", "password"]

    def validate(self, attrs):
        email = (attrs.get("email") or "").strip().lower()
        password = attrs.get("password") or ""

        user = User.objects.filter(email__iexact=email).first()
        if user is None or not user.check_password(password):
            raise AuthenticationFailed("No active account found with the given credentials")

        refresh = self.get_token(user)
        try:
            profile = user.profile
        except Profile.DoesNotExist:
            profile = None

        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "username": user.username,
            "email": user.email,
            "full_name": (profile.full_name if profile else "") or user.username,
        }


class ProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.CharField(source="user.email", read_only=True)
    avatar_url = serializers.SerializerMethodField()

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
            "avatar_url",
        ]

    def get_avatar_url(self, obj):
        if not obj.avatar:
            return ""
        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(obj.avatar.url)
        return obj.avatar.url


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
