import random

from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand

from community.models import Comment, Post, PostLike, SavedPost
from documents.models import Document
from groups_app.models import GroupMember, JoinRequest, StudyGroup
from users.models import Profile


class Command(BaseCommand):
    help = "Seed full demo data for profile, community, documents, and groups."

    def handle(self, *args, **options):
        random.seed(641)

        users = self._seed_users()
        posts = self._seed_community(users)
        self._seed_documents(users)
        self._seed_groups(users)

        self.stdout.write(
            self.style.SUCCESS(
                f"Seeded {len(users)} users, {len(posts)} posts, "
                f"{Document.objects.count()} documents, {StudyGroup.objects.count()} groups."
            )
        )

    def _seed_users(self):
        majors = ["CNTT", "ATTT", "DTVT", "MMT", "KHDL"]
        classes = ["D22CNPM01", "D22ATTT02", "D22DTVT03", "D22MMT04", "D22KHDL05"]
        addresses = ["Hà Đông", "Cầu Giấy", "Thanh Xuân", "Long Biên", "Đống Đa"]

        users = []
        for i in range(1, 16):
            username = f"sv_b22_{i:03d}"
            email = f"{username}@stu.ptit.edu.vn"
            user, _ = User.objects.get_or_create(username=username, defaults={"email": email})
            if not user.email:
                user.email = email
            user.set_password("12345678")
            user.save()

            profile, _ = Profile.objects.get_or_create(user=user)
            profile.full_name = f"Sinh Vien {i:03d}"
            profile.student_id = f"B22DCCN{i:03d}"
            profile.class_code = random.choice(classes)
            profile.phone = f"09{random.randint(10000000, 99999999)}"
            profile.gender = random.choice(["Nam", "Nữ"])
            profile.date_of_birth = f"{random.randint(1,28):02d}/{random.randint(1,12):02d}/2004"
            profile.address = random.choice(addresses)
            profile.major = random.choice(majors)
            profile.bio = "Sinh viên PTIT - sẵn sàng kết nối học tập."
            profile.save()
            users.append(user)
        return users

    def _seed_community(self, users):
        topics = ["Flutter", "Django", "Database", "AI", "UIUX"]
        Post.objects.all().delete()
        Comment.objects.all().delete()
        PostLike.objects.all().delete()
        SavedPost.objects.all().delete()

        posts = []
        for i in range(1, 41):
            author = random.choice(users)
            topic = random.choice(topics)
            post = Post.objects.create(
                author=author,
                title=f"[{topic}] Chia sẻ học tập #{i}",
                content=f"Bài viết {i} về {topic}: tổng hợp tài nguyên và kinh nghiệm học phần.",
                topic=topic,
            )
            posts.append(post)

        for post in posts:
            commenters = random.sample(users, k=random.randint(2, 5))
            for user in commenters:
                Comment.objects.create(
                    post=post,
                    author=user,
                    content=f"Mình quan tâm chủ đề {post.topic}, cảm ơn chia sẻ.",
                )
            likers = random.sample(users, k=random.randint(3, 9))
            for user in likers:
                PostLike.objects.get_or_create(post=post, user=user)
            savers = random.sample(users, k=random.randint(1, 5))
            for user in savers:
                SavedPost.objects.get_or_create(post=post, user=user)
        return posts

    def _seed_documents(self, users):
        subjects = ["Flutter", "Python", "Java", "AI", "Database", "Web"]
        categories = ["Giáo trình", "Slide", "Đề thi", "Báo cáo", "Ghi chú"]
        doc_types = ["slide", "report", "exam", "note", "other"]

        Document.objects.all().delete()
        for i in range(1, 31):
            uploader = random.choice(users)
            subject = random.choice(subjects)
            category = random.choice(categories)
            doc = Document(
                uploader=uploader,
                title=f"{subject} - Tài liệu #{i}",
                subject=subject,
                category=category,
                document_type=random.choice(doc_types),
                description=f"Tài liệu {subject} thuộc nhóm {category}, dùng để ôn tập.",
                download_count=random.randint(0, 200),
            )
            content = f"Tài liệu mẫu #{i}\nMôn học: {subject}\nDanh mục: {category}\n"
            doc.file.save(f"doc_{i:03d}.txt", ContentFile(content.encode("utf-8")), save=False)
            doc.save()

    def _seed_groups(self, users):
        subjects = ["Flutter", "Django", "Data Mining", "Computer Vision", "Database"]
        categories = ["Đồ án", "Ôn thi", "Nghiên cứu", "Học nhóm"]

        GroupMember.objects.all().delete()
        JoinRequest.objects.all().delete()
        StudyGroup.objects.all().delete()

        groups = []
        for i in range(1, 13):
            owner = random.choice(users)
            group = StudyGroup.objects.create(
                owner=owner,
                title=f"Nhóm học tập #{i}",
                subject=random.choice(subjects),
                category=random.choice(categories),
                description="Nhóm trao đổi bài tập lớn và chia sẻ tài liệu.",
                avatar_url="https://picsum.photos/seed/ptit-group/200/200",
                max_members=random.randint(5, 10),
            )
            GroupMember.objects.get_or_create(group=group, user=owner)
            groups.append(group)

        for group in groups:
            candidates = [u for u in users if u != group.owner]
            for user in random.sample(candidates, k=random.randint(2, 5)):
                status = random.choice(["pending", "approved", "rejected"])
                req, _ = JoinRequest.objects.get_or_create(
                    group=group, user=user, defaults={"status": status}
                )
                req.status = status
                req.save()
                if status == "approved":
                    GroupMember.objects.get_or_create(group=group, user=user)
