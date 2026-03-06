#!/bin/bash
sed -i 's/const EdgeInsets/EdgeInsets/g' lib/user/screens/group_details_screen.dart
sed -i 's/const TextStyle/TextStyle/g' lib/user/screens/group_details_screen.dart
sed -i 's/const CircularProgressIndicator/CircularProgressIndicator/g' lib/user/screens/tabs/add_friends_tab.dart
sed -i 's/const SnackBar/SnackBar/g' lib/user/screens/tabs/settings_tab.dart
sed -i 's/const Padding/Padding/g' lib/user/widgets/whatsapp_link_sheet.dart
sed -i 's/const EdgeInsets/EdgeInsets/g' lib/user/widgets/whatsapp_link_sheet.dart
sed -i 's/const \[/\[/g' lib/user/widgets/whatsapp_link_sheet.dart
