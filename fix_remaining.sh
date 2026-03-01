#!/bin/bash
sed -i -E 's/const (Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/auth/screens/login_screen.dart
sed -i -E 's/const (Center\(.*Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/auth/screens/login_screen.dart
sed -i -E 's/const (Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/auth/screens/intro_screen.dart 
sed -i -E 's/const (Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/user/screens/group_details_screen.dart
sed -i -E 's/const (Flexible.*Text.*AppColors)/\1/g' lib/user/screens/group_details_screen.dart
sed -i -E 's/const (Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/user/screens/tabs/add_friends_tab.dart
sed -i -E 's/const (SnackBar\(content: Text\([^,]+\).*AppColors)/\1/g' lib/user/screens/tabs/settings_tab.dart
sed -i -E 's/const (Text\([^,]+,\s+style:.+AppColors)/\1/g' lib/user/widgets/whatsapp_link_sheet.dart
sed -i -E 's/const (Row\(.*AppColors)/\1/g' lib/user/widgets/whatsapp_link_sheet.dart
