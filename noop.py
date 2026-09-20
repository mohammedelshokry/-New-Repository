import codecs

with codecs.open('mobile-app/lib/screens/admin_dashboard_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

old_actions = """        actions: [
          IconButton(
            tooltip: 'تسجيل خروج',"""

new_actions = """        actions: [
          IconButton(
            tooltip: 'معاينة التطبيق',
            icon: const Icon(Icons.phone_iphone, color: Colors.white),
            onPressed: () {
              // We'll push the Home tab or map
              // Wait, HomeOrOwnerWrapper blocks them if they go to /home.
              // So let's push a specific screen? Or no, let's just keep it simple.
            },
          ),
          IconButton(
            tooltip: 'تسجيل خروج',"""

# Nevermind, let's just leave it simple for now as it's a dedicated admin panel.
