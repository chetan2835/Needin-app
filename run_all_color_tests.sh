#!/bin/bash

echo "=================================================="
echo "    STARTING COMPREHENSIVE COLOR MIGRATION TEST   "
echo "=================================================="

# Step 1: Run the Dart CLI Script Verification
echo ""
echo "[STEP 1/3] Running verify_color_migration.dart..."
dart run verify_color_migration.dart
STEP1_EXIT=$?

# Step 2: Run Widget Tests
echo ""
echo "[STEP 2/3] Running flutter test test/color_migration_test.dart..."
flutter test test/color_migration_test.dart --reporter=expanded
STEP2_EXIT=$?

# Step 3: Run Theme Unit Tests
echo ""
echo "[STEP 3/3] Running flutter test test/theme_color_test.dart..."
flutter test test/theme_color_test.dart --reporter=expanded
STEP3_EXIT=$?

# Step 4: Final Summary
echo ""
echo "=================================================="
echo "                TEST SUITE SUMMARY                "
echo "=================================================="

if [ $STEP1_EXIT -eq 0 ]; then
  echo "✅ Step 1: File Content Verification PASS"
else
  echo "❌ Step 1: File Content Verification FAIL (Check output above for details)"
fi

if [ $STEP2_EXIT -eq 0 ]; then
  echo "✅ Step 2: Widget Color Tests PASS"
else
  echo "❌ Step 2: Widget Color Tests FAIL (Check output above for details)"
fi

if [ $STEP3_EXIT -eq 0 ]; then
  echo "✅ Step 3: Theme Configuration Tests PASS"
else
  echo "❌ Step 3: Theme Configuration Tests FAIL (Check output above for details)"
fi

echo "=================================================="

if [ $STEP1_EXIT -eq 0 ] && [ $STEP2_EXIT -eq 0 ] && [ $STEP3_EXIT -eq 0 ]; then
  echo "🎉 SUCCESS: THE COLOR MIGRATION IS 100% VERIFIED AND COMPLETE! 🎉"
  exit 0
else
  echo "⚠️ FAILURE: ONE OR MORE COLOR VERIFICATION STEPS FAILED."
  exit 1
fi
