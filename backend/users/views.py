from rest_framework import generics, permissions

from core.demo_auth import resolve_demo_user

from .serializers import ProfileSerializer, RegisterSerializer


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = ProfileSerializer
    permission_classes = [permissions.AllowAny]

    def get_object(self):
        if self.request.user.is_authenticated:
            return self.request.user.profile
        return resolve_demo_user(self.request).profile
