# Burner List for iOS

Native SwiftUI client for the existing Burner List Supabase backend.

## Requirements

- macOS with the current stable Xcode and an iOS Simulator runtime
- An Apple development team for physical-device builds

Copy `Config.example.xcconfig` to `Config.xcconfig`, then replace the placeholders
with the public Supabase URL and anonymous key used by the web client. The local
config file is ignored by Git. Never add a Supabase service-role key to this
project.

Open `BurnerList.xcodeproj`, select the `BurnerList` scheme, and run it on an
iPhone simulator. For a physical-device build, choose your own development team
in Xcode's Signing & Capabilities panel.

The current native milestone supports email and Google sign-in, four task scopes
(Today's List, All Tasks, Upcoming, and Previous), switching Burner Lists, task
editing and scheduling, and Burner/Kanban/List layouts. Before Google sign-in can return to the app,
add `burnerlist://auth-callback` to Supabase Dashboard → Authentication → URL
Configuration → Redirect URLs.

SwiftData-backed offline mutations, drag reordering, and account deletion remain
the next milestones.
