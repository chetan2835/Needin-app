import 'dart:io';
import 'dart:convert';

void main() async {
  // Read .env file manually
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print("Error: .env file not found");
    exit(1);
  }

  String? supabaseUrl;
  String? supabaseAnonKey;

  final lines = await envFile.readAsLines();
  for (var line in lines) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.substring('SUPABASE_URL='.length).trim();
      if (supabaseUrl.startsWith('"') && supabaseUrl.endsWith('"')) {
        supabaseUrl = supabaseUrl.substring(1, supabaseUrl.length - 1);
      }
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseAnonKey = line.substring('SUPABASE_ANON_KEY='.length).trim();
      if (supabaseAnonKey.startsWith('"') && supabaseAnonKey.endsWith('"')) {
        supabaseAnonKey = supabaseAnonKey.substring(1, supabaseAnonKey.length - 1);
      }
    }
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print("Error: Supabase credentials not found in .env");
    exit(1);
  }

  try {
    print("Fetching profiles...");
    int total = 0;
    int validEmail = 0;
    int noEmail = 0;
    int emptyEmail = 0;
    int malformedEmail = 0;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    // Use HttpClient to avoid any external packages
    final httpClient = HttpClient();
    
    bool hasMore = true;
    int offset = 0;
    const limit = 1000;

    while (hasMore) {
      final uri = Uri.parse('$supabaseUrl/rest/v1/profiles?select=email&offset=$offset&limit=$limit');
      final request = await httpClient.getUrl(uri);
      request.headers.add('apikey', supabaseAnonKey);
      request.headers.add('Authorization', 'Bearer $supabaseAnonKey');
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode != 200) {
        print("Error API: $responseBody");
        break;
      }
      
      final List<dynamic> profiles = jsonDecode(responseBody);
      if (profiles.isEmpty) {
        hasMore = false;
        break;
      }
      
      total += profiles.length;
      
      for (var p in profiles) {
        final email = p['email']?.toString();

        if (email == null) {
          noEmail++;
        } else if (email.trim().isEmpty) {
          emptyEmail++;
        } else if (!emailRegex.hasMatch(email.trim())) {
          malformedEmail++;
        } else {
          validEmail++;
        }
      }
      
      if (profiles.length < limit) {
        hasMore = false;
      } else {
        offset += limit;
      }
    }

    print("\n====================================================");
    print("EXISTING USER ANALYSIS");
    print("====================================================");
    print("1. Total number of users: $total");
    int pctBase = total == 0 ? 1 : total; // prevent divide by zero
    print("2. Number of users with a valid email stored: $validEmail (${(validEmail/pctBase*100).toStringAsFixed(2)}%)");
    print("3. Number of users with no email stored (null): $noEmail (${(noEmail/pctBase*100).toStringAsFixed(2)}%)");
    print("4. Number of users with empty-string emails: $emptyEmail (${(emptyEmail/pctBase*100).toStringAsFixed(2)}%)");
    print("5. Number of users with malformed/invalid emails: $malformedEmail (${(malformedEmail/pctBase*100).toStringAsFixed(2)}%)");
    print("6. Number of users already marked as email_verified: 0 (0.00%) (Column missing)");
    print("7. Number of users not verified: $total (100.00%)");
    print("====================================================\n");

  } catch (e) {
    print("Error querying database: $e");
  } finally {
    exit(0);
  }
}
