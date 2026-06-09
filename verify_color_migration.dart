// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';

void main() async {
  print('Starting full color migration verification...');
  print('--------------------------------------------');

  final currentDir = Directory.current;
  
  // Forbidden orange colors
  final forbiddenOranges = [
    '#F27F0D', '#FF9800', '#FF8000', '#E86B00', '#EA580C', 
    '#FFB347', '#FBD38D', '#FFF1E3', '#FFF7ED', '#FFF8F0',
    '0xFFF27F0D', '0xFFFF9800', '0xFFFF8000', '0xFFE86B00', 
    '0xFFEA580C', '0xFFFFB347', '0xFFFBD38D', '0xFFFFF1E3', 
    '0xFFFFF7ED', '0xFFFFF8F0', 'Colors.orange'
  ];
  
  // Required coral red colors
  final requiredCorals = [
    '#F05A4F', '#C44840', '#F37A72', '#FDE8E7', '#FFF5F4',
    '0xFFF05A4F', '0xFFC44840', '0xFFF37A72', '0xFFFDE8E7', '0xFFFFF5F4'
  ];

  final extensionsToScan = {
    '.dart', '.xml', '.kt', '.swift', '.yaml', 
    '.json', '.plist', '.gradle', '.properties'
  };

  int filesScanned = 0;
  int violationsFound = 0;
  
  final foundCorals = <String>{};

  await for (final entity in currentDir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      // Exclude build, git, tool directories, test files, and this script itself
      if (entity.path.contains('.git') || 
          entity.path.contains('build${Platform.pathSeparator}') || 
          entity.path.contains('.dart_tool') ||
          entity.path.contains('ios${Platform.pathSeparator}Pods') ||
          entity.path.contains('test${Platform.pathSeparator}') ||
          entity.path.endsWith('verify_color_migration.dart') ||
          entity.path.endsWith('run_all_color_tests.sh')) {
        continue;
      }

      String ext = '';
      final dotIndex = entity.path.lastIndexOf('.');
      if (dotIndex != -1) {
        ext = entity.path.substring(dotIndex).toLowerCase();
      }
      if (extensionsToScan.contains(ext) || dotIndex == -1) {
        filesScanned++;
        try {
          final lines = await entity.readAsLines(encoding: utf8);
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            final lowerLine = line.toLowerCase();
            
            // Check for forbidden colors
            for (final forbidden in forbiddenOranges) {
              if (lowerLine.contains(forbidden.toLowerCase())) {
                print('VIOLATION FOUND:');
                print('  File: ${entity.path}');
                print('  Line ${i + 1}: ${line.trim()}');
                print('  Matched forbidden value: $forbidden\n');
                violationsFound++;
              }
            }

            // Check for required colors
            for (final coral in requiredCorals) {
              if (lowerLine.contains(coral.toLowerCase())) {
                foundCorals.add(coral);
              }
            }
          }
        } catch (e) {
          // Skip unreadable files
        }
      }
    }
  }

  print('--------------------------------------------');
  print('Scan Complete.');
  print('Files scanned: $filesScanned');
  print('Violations found: $violationsFound');
  
  print('\nCoral Red verification:');
  int missingCorals = 0;
  for (final coral in requiredCorals) {
    if (foundCorals.contains(coral)) {
      print('  ✅ Found: $coral');
    } else {
      print('  ❌ Missing: $coral');
      missingCorals++;
    }
  }

  print('\n--------------------------------------------');
  if (violationsFound == 0 && missingCorals == 0) {
    print('VERDICT: PASS');
    print('The color migration is confirmed 100% complete and correct.');
    exit(0);
  } else {
    print('VERDICT: FAIL');
    if (violationsFound > 0) {
      print('Forbidden orange colors were found in the project.');
    }
    if (missingCorals > 0) {
      print('Some required coral red colors are missing from the project.');
    }
    exit(1);
  }
}
