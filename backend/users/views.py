from rest_framework import generics, permissions

from core.demo_auth import resolve_demo_user

from .models import Profile
from .serializers import ProfileSerializer, RegisterSerializer


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = ProfileSerializer
    permission_classes = [permissions.AllowAny]

    def get_object(self):
        target_username = (self.request.query_params.get("target_username") or "").strip().lower()
        if target_username:
            from django.contrib.auth.models import User

            user = User.objects.filter(username=target_username).first()
            if user:
                profile, _ = Profile.objects.get_or_create(user=user)
                return profile
        user = resolve_demo_user(self.request)
        profile, _ = Profile.objects.get_or_create(user=user)
        return profile
