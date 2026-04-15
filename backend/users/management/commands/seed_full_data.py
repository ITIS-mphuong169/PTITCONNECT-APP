import random
import requests
import unicodedata
from collections import defaultdict

from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.utils import timezone

from users.models import Profile, FriendRequest
from chat_app.models import Conversation, Message
from notifications_app.models import Notification

from community.models import Comment, Post, PostLike, SavedPost
from documents.models import Document
from groups_app.models import GroupMember, JoinRequest, StudyGroup


def remove_accents(text):
    return ''.join(
        c for c in unicodedata.normalize('NFD', text)
        if unicodedata.category(c) != 'Mn'
    )


def generate_ptit_email(full_name, student_id):
    """
    Ví dụ:
    Nguyễn Văn Nam + B22DCCN666
    -> NamNV.B22CN666@stu.ptit.edu.vn
    """
    name_ascii = remove_accents(full_name).strip()
    parts = [p for p in name_ascii.split() if p]

    if len(parts) < 2:
        return f"{student_id}@stu.ptit.edu.vn"

    first_name = parts[-1].capitalize()
    initials = ''.join(p[0].upper() for p in parts[:-1])

    first3 = student_id[:3].upper()
    last5 = student_id[-5:].upper()

    return f"{first_name}{initials}.{first3}{last5}@stu.ptit.edu.vn"


class Command(BaseCommand):
    help = "FULL SEED ALL SYSTEM"

    PASSWORD = "123456"
    TOTAL_USERS = 100
    FRIENDS_PER_USER = 25
    PENDING_PER_USER = 15
    CHAT_PARTNERS_PER_USER = 15
    NOTIFICATIONS_PER_USER = 20

    def handle(self, *args, **kwargs):
        random.seed(42)

        self.stdout.write("RESET DATA...")
        self.reset_all()

        self.stdout.write("USERS...")
        users = self.create_users()

        self.stdout.write("FRIENDS...")
        friend_map = self.create_friends(users)

        self.stdout.write("REQUESTS...")
        pending_out, pending_in = self.create_requests(users, friend_map)

        self.stdout.write("CHAT...")
        conv_map = self.create_chat(users, friend_map)

        self.stdout.write("NOTIFICATIONS...")
        self.create_notifications(users, friend_map, pending_in, conv_map)

        self.stdout.write("COMMUNITY...")
        self.seed_community(users)

        self.stdout.write("DOCUMENTS...")
        self.seed_documents(users)

        self.stdout.write("GROUPS...")
        self.seed_groups(users)

        self.stdout.write(self.style.SUCCESS("DONE FULL SEED"))
        self.stdout.write(
            self.style.SUCCESS(
                f"Users={User.objects.count()}, "
                f"Profiles={Profile.objects.count()}, "
                f"FriendRequests={FriendRequest.objects.count()}, "
                f"Conversations={Conversation.objects.count()}, "
                f"Messages={Message.objects.count()}, "
                f"Notifications={Notification.objects.count()}, "
                f"Posts={Post.objects.count()}, "
                f"Documents={Document.objects.count()}, "
                f"Groups={StudyGroup.objects.count()}"
            )
        )
        self.stdout.write(self.style.WARNING("Demo login: sv001 / 123456"))

    def reset_all(self):
        Notification.objects.all().delete()
        Message.objects.all().delete()
        Conversation.objects.all().delete()
        FriendRequest.objects.all().delete()

        Comment.objects.all().delete()
        PostLike.objects.all().delete()
        SavedPost.objects.all().delete()
        Post.objects.all().delete()

        Document.objects.all().delete()

        GroupMember.objects.all().delete()
        JoinRequest.objects.all().delete()
        StudyGroup.objects.all().delete()

        Profile.objects.all().delete()
        User.objects.all().delete()

    def create_users(self):
        first_names = [
            "An", "Bình", "Châu", "Dũng", "Giang", "Hà", "Huy", "Khánh", "Lâm",
            "Linh", "Minh", "Nam", "Nga", "Ngọc", "Nhung", "Phúc", "Phương",
            "Quân", "Quỳnh", "Sơn", "Thảo", "Thành", "Trang", "Tuấn", "Vy",
        ]
        middle_names = [
            "Anh", "Bảo", "Công", "Đức", "Gia", "Hoài", "Hồng", "Hữu", "Khắc",
            "Mai", "Minh", "Ngọc", "Quang", "Quốc", "Thanh", "Thị", "Trọng",
            "Tuệ", "Văn", "Xuân",
        ]
        last_names = [
            "Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan",
            "Vũ", "Võ", "Đặng", "Bùi", "Đỗ", "Hồ", "Ngô", "Dương",
        ]
        classes = ["D22CNPM01", "D22ATTT02", "D22DTVT03", "D22MMT04", "D22KHDL05"]
        majors = ["CNTT", "ATTT", "DTVT", "MMT", "KHDL"]
        addresses = ["Hà Nội", "Bắc Ninh", "Hưng Yên", "Hải Dương", "Nam Định"]

        users = []
        for i in range(1, self.TOTAL_USERS + 1):
            username = f"sv{i:03d}"
            student_id = f"B22DCCN{i:03d}"

            full_name = (
                f"{random.choice(last_names)} "
                f"{random.choice(middle_names)} "
                f"{random.choice(first_names)}"
            )
            email = generate_ptit_email(full_name, student_id)

            user = User.objects.create_user(
                username=username,
                password=self.PASSWORD,
                email=email,
            )

            profile, _ = Profile.objects.get_or_create(user=user)
            profile.full_name = full_name
            profile.student_id = student_id
            profile.class_code = random.choice(classes)
            profile.major = random.choice(majors)
            profile.phone = f"09{random.randint(10000000, 99999999)}"
            profile.gender = random.choice(["Nam", "Nữ"])
            profile.date_of_birth = (
                f"{random.randint(1, 28):02d}/{random.randint(1, 12):02d}/2004"
            )
            profile.address = random.choice(addresses)
            profile.bio = "Sinh viên PTIT - sẵn sàng kết nối học tập."

            try:
                gender_query = "male" if profile.gender == "Nam" else "female"
                res = requests.get(
                    f"https://randomuser.me/api/?gender={gender_query}",
                    timeout=5,
                )
                data = res.json()
                avatar_url = data["results"][0]["picture"]["large"]
                img_res = requests.get(avatar_url, timeout=5)

                profile.avatar.save(
                    f"{username}.jpg",
                    ContentFile(img_res.content),
                    save=False,
                )
            except Exception as e:
                print("Avatar error:", e)

            profile.save()
            users.append(user)

        return users

    def create_friends(self, users):
        """
        100 user:
        offset 1..12 và 50 => đúng 25 bạn / user
        """
        n = len(users)
        friend_map = {u.id: set() for u in users}
        offsets = list(range(1, 13)) + [n // 2]

        for i in range(n):
            for off in offsets:
                j = (i + off) % n
                u1, u2 = users[i], users[j]

                if u2.id in friend_map[u1.id]:
                    continue

                FriendRequest.objects.create(
                    from_user=u1,
                    to_user=u2,
                    status="accepted",
                )
                friend_map[u1.id].add(u2.id)
                friend_map[u2.id].add(u1.id)

        return friend_map

    def create_requests(self, users, friend_map):
        """
        15 lời mời pending / user, không đụng accepted.
        Phần user còn lại sẽ là gợi ý kết bạn.
        """
        pending_out = defaultdict(set)
        pending_in = defaultdict(set)

        offsets = [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28]

        for i in range(len(users)):
            for off in offsets:
                j = (i + off) % len(users)
                u1, u2 = users[i], users[j]

                if u2.id in friend_map[u1.id]:
                    continue
                if u2.id in pending_out[u1.id]:
                    continue
                if u1.id in pending_out[u2.id]:
                    continue

                FriendRequest.objects.create(
                    from_user=u1,
                    to_user=u2,
                    status="pending",
                )
                pending_out[u1.id].add(u2.id)
                pending_in[u2.id].add(u1.id)

        return pending_out, pending_in

    def create_chat(self, users, friend_map):
        """
        15 chat partners / user.
        20-30 messages / conversation.
        """
        conv_map = defaultdict(list)
        offsets = list(range(1, 8)) + [len(users) // 2]

        samples = [
            "Chào bạn, hôm nay học nhóm không?",
            "Mình vừa up tài liệu mới, bạn xem nhé.",
            "Mai kiểm tra rồi, ôn phần database chưa?",
            "Bạn có note môn Flutter không, cho mình xin với.",
            "Tối nay họp nhóm lúc 8h nha.",
            "Cảm ơn bạn, tài liệu rất hữu ích.",
            "Mình đang làm bài này, bạn xem giúp được không?",
            "Chiều nay lên thư viện không?",
            "Bạn nhớ deadline nộp báo cáo chứ?",
            "Đoạn API này mình vẫn chưa hiểu lắm.",
            "Bạn check tin nhắn giúp mình nhé.",
            "Slide hôm trước mình gửi ở nhóm rồi đó.",
            "Phần UI bạn làm đẹp thật.",
            "Tí nữa call nhóm nhé.",
            "Mình vừa sửa xong backend rồi.",
        ]

        for i in range(len(users)):
            for off in offsets:
                j = (i + off) % len(users)
                u1, u2 = users[i], users[j]

                if u2.id not in friend_map[u1.id]:
                    continue
                if u1.id > u2.id:
                    continue

                conv = Conversation.objects.create(
                    user1=u1,
                    user2=u2,
                    updated_at=timezone.now(),
                )

                for _ in range(random.randint(20, 30)):
                    msg = Message.objects.create(
                        conversation=conv,
                        sender=random.choice([u1, u2]),
                        content=random.choice(samples),
                    )
                    conv.updated_at = getattr(msg, "created_at", timezone.now())

                conv.save()
                conv_map[u1.id].append(conv)
                conv_map[u2.id].append(conv)

        return conv_map

    def create_notifications(self, users, friend_map, pending_in, conv_map):
        for u in users:
            count = 0

            for sender_id in list(pending_in[u.id])[:5]:
                sender = User.objects.get(id=sender_id)
                Notification.objects.create(
                    user=u,
                    title="Lời mời kết bạn mới",
                    content=f"{sender.username} đã gửi lời mời kết bạn cho bạn.",
                    notification_type="friend_request",
                    target_username=sender.username,
                    is_read=False,
                )
                count += 1

            for fid in list(friend_map[u.id])[:5]:
                friend = User.objects.get(id=fid)
                Notification.objects.create(
                    user=u,
                    title="Bạn mới",
                    content=f"Bạn và {friend.username} hiện đã là bạn bè.",
                    notification_type="friend_accept",
                    target_username=friend.username,
                    is_read=False,
                )
                count += 1

            for conv in conv_map[u.id][:5]:
                other = conv.user2 if conv.user1_id == u.id else conv.user1
                Notification.objects.create(
                    user=u,
                    title="Tin nhắn mới",
                    content=f"{other.username} đã gửi tin nhắn cho bạn.",
                    notification_type="message",
                    target_username=other.username,
                    conversation_id=conv.id,
                    is_read=False,
                )
                count += 1

            while count < 20:
                Notification.objects.create(
                    user=u,
                    title="Thông báo hệ thống",
                    content="Có cập nhật mới trong ứng dụng.",
                    notification_type="system",
                    is_read=False,
                )
                count += 1

    def seed_community(self, users):
        posts = []
        for i in range(40):
            p = Post.objects.create(
                author=random.choice(users),
                title=f"Bài viết {i + 1}",
                content="Demo content",
                topic=random.choice(["CNTT", "Flutter", "Django", "AI", "Database"]),
            )
            posts.append(p)

        for p in posts:
            for u in random.sample(users, 5):
                Comment.objects.create(post=p, author=u, content="Hay!")
            for u in random.sample(users, 5):
                PostLike.objects.get_or_create(post=p, user=u)
            for u in random.sample(users, 3):
                SavedPost.objects.get_or_create(post=p, user=u)

        return posts

    def seed_documents(self, users):
        for i in range(30):
            doc = Document(
                uploader=random.choice(users),
                title=f"Doc {i + 1}",
                subject=random.choice(["CNTT", "Flutter", "Python", "Database"]),
                category=random.choice(["Slide", "Giáo trình", "Đề thi", "Ghi chú"]),
                document_type=random.choice(["slide", "report", "exam", "note", "other"]),
                description="Demo",
            )
            doc.file.save(
                f"doc{i + 1}.txt",
                ContentFile(b"demo"),
                save=False,
            )
            doc.save()

    def seed_groups(self, users):
        for i in range(10):
            owner = random.choice(users)
            g = StudyGroup.objects.create(
                owner=owner,
                title=f"Group {i + 1}",
                subject=random.choice(["CNTT", "Flutter", "Django", "Database"]),
                category="Hoc tap",
                description="Nhóm học tập demo",
                max_members=10,
            )

            GroupMember.objects.get_or_create(group=g, user=owner)

            candidates = [u for u in users if u != owner]
            for u in random.sample(candidates, 5):
                status = random.choice(["pending", "approved", "rejected"])
                req = JoinRequest.objects.create(
                    group=g,
                    user=u,
                    status=status,
                )
                if req.status == "approved":
                    GroupMember.objects.get_or_create(group=g, user=u)