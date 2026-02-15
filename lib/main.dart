import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- 1. CONFIGURATION ---
class SupabaseConfig {
  // Replace with your actual project URL
  static const String supabaseUrl = 'https://zrodayjdpcqiilnxerix.supabase.co';

  // Replace with your actual Anon Key
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpyb2RheWpkcGNxaWlsbnhlcml4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5ODg5ODYsImV4cCI6MjA4NjU2NDk4Nn0.4GQZV2vZHqMBFsB4bYzEu2GO2bUwnjRYdboCQXXfMBY';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(MaterialApp(
    title: 'AI Talent Scout',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, fontFamily: 'sans-serif'),
    home: const AuthGate(),
  ));
}

final supabase = Supabase.instance.client;

// --- 2. AUTH GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return ProfessionalAIScout();
        }
        return const LoginPage();
      },
    );
  }
}

// --- 3. COMPACT LOGIN PAGE (Updated) ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _handleAuth(bool isGoogle) async {
    setState(() => _isLoading = true);
    try {
      if (isGoogle) {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000/', // Ensure this matches your running port
        );
      } else {
        if (_isSignUp) {
          await supabase.auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            data: {'display_name': _nameController.text.trim()},
          );
          if (mounted) _msg("Account created! Check email.");
        } else {
          await supabase.auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        }
      }
    } catch (e) {
      if (mounted) _msg("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String txt, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(txt),
      backgroundColor: isError ? Colors.redAccent : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView( // Safety net for small screens
          child: Container(
            width: 320, // TIGHT WIDTH
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Hugs content tightly
              children: [
                const Icon(Icons.psychology, size: 40, color: Colors.blueAccent),
                const SizedBox(height: 10),
                Text(_isSignUp ? "JOIN" : "LOGIN",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),

                // Compact Google Button
                OutlinedButton.icon(
                  onPressed: () => _handleAuth(true),
                  icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.white), // Use generic icon if image fails
                  label: const Text("Google", style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Colors.white12)
                ),

                if (_isSignUp) ...[
                  _compactField(_nameController, "Name", Icons.person),
                  const SizedBox(height: 10),
                ],
                _compactField(_emailController, "Email", Icons.email),
                const SizedBox(height: 10),
                _compactField(_passwordController, "Pass", Icons.lock, isPass: true),

                const SizedBox(height: 20),
                if (_isLoading)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  ElevatedButton(
                    onPressed: () => _handleAuth(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_isSignUp ? "SIGN UP" : "ENTER"),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? "Login?" : "Create Account?",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactField(TextEditingController c, String h, IconData i, {bool isPass = false}) {
    return SizedBox(
      height: 40, // Fixed small height
      child: TextField(
        controller: c,
        obscureText: isPass,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          prefixIcon: Icon(i, size: 16, color: Colors.white38),
          hintText: h,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

// --- 4. RESPONSIVE DASHBOARD (Fixed Overflow) ---
class ProfessionalAIScout extends StatefulWidget {
  @override
  _ProfessionalAIScoutState createState() => _ProfessionalAIScoutState();
}

class _ProfessionalAIScoutState extends State<ProfessionalAIScout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final jdController = TextEditingController();
  final roleController = TextEditingController();
  final skillsController = TextEditingController();

  double score = 0.0;
  List found = [];
  List missing = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> processResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null && result.files.first.bytes != null) {
      setState(() => loading = true);

      // Use localhost for Web. If Android Emulator, use 10.0.2.2
      // NEW (Correct)
      var request = http.MultipartRequest('POST', Uri.parse('https://ai-talent-scout.onrender.com'));
      String finalJD = _tabController.index == 0 ? jdController.text : "${roleController.text} ${skillsController.text}";

      request.fields['job_desc'] = finalJD;
      request.files.add(http.MultipartFile.fromBytes('resume', result.files.first.bytes!, filename: "resume.pdf"));

      try {
        var streamedRes = await request.send();
        var res = await http.Response.fromStream(streamedRes);
        var data = jsonDecode(res.body);

        setState(() {
          score = (data['match_percent'] as num).toDouble();
          found = data['found'];
          missing = data['missing'];
          loading = false;
        });

        await saveToSupabase(
          fileName: result.files.first.name,
          jobDescription: finalJD,
          matchPercent: score,
          matchedSkills: found.cast<String>(),
          missingSkills: missing.cast<String>(),
        );
      } catch (e) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backend Connection Error!")));
      }
    }
  }

  Future<void> saveToSupabase({
    required String fileName,
    required String jobDescription,
    required double matchPercent,
    required List<String> matchedSkills,
    required List<String> missingSkills,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final resumeResponse = await supabase.from('resumes').insert({
        'file_name': fileName,
        'user_id': user.id,
      }).select().single();

      final resumeId = resumeResponse['id'];

      final jobDescResponse = await supabase.from('job_descriptions').insert({
        'title': roleController.text.isNotEmpty ? roleController.text : 'Analysis',
        'description': jobDescription,
        'user_id': user.id,
      }).select().single();

      final jobDescId = jobDescResponse['id'];

      await supabase.from('analysis_results').insert({
        'resume_id': resumeId,
        'job_description_id': jobDescId,
        'match_percent': matchPercent,
        'matched_skills': matchedSkills,
        'missing_skills': missingSkills,
        'user_id': user.id,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved to history!")));
    } catch (e) {
      print("Supabase Save Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200), // Prevent massive stretch
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        // Using Column with Expanded prevents "RenderFlex overflowed"
                        child: Column(
                          children: [
                            _header(),
                            const SizedBox(height: 30),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Switch Layout based on width
                                  bool isWide = constraints.maxWidth > 800;

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: _inputPanel()),
                                        const SizedBox(width: 40),
                                        Expanded(flex: 2, child: _resultsPanel()),
                                      ],
                                    );
                                  } else {
                                    // On narrow screens, we scroll internally
                                    return SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          _inputPanel(),
                                          const SizedBox(height: 40),
                                          _resultsPanel(),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final userEmail = supabase.auth.currentUser?.email ?? "User";
    final displayName = supabase.auth.currentUser?.userMetadata?['display_name'] ?? userEmail;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("AI TALENT SCOUT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            Text("Hello, $displayName", style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.logout, color: Colors.white54), onPressed: () => supabase.auth.signOut(), tooltip: "Logout"),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: loading ? null : processResume,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text("SCAN"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputPanel() {
    return Column(
      children: [
        TabBar(controller: _tabController, indicatorColor: Colors.blueAccent, tabs: const [Tab(text: "Description Mode"), Tab(text: "Keyword Mode")]),
        const SizedBox(height: 20),
        // Expanded fills the remaining vertical space for the input
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _styledTextField(jdController, "Paste full job description...", true),
              Column(children: [
                _styledTextField(roleController, "Target Role", false),
                const SizedBox(height: 15),
                _styledTextField(skillsController, "Specific Skills", false)
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultsPanel() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              builder: (context, value, child) {
                return Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withOpacity(1 - value), width: 2 + (8 * value))));
              },
              onEnd: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            const Text("AI SCANNING...", style: TextStyle(color: Colors.blueAccent, letterSpacing: 2, fontSize: 10)),
          ],
        ),
      );
    }

    // Only scroll the results list if it gets too long
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 140, height: 140, child: CircularProgressIndicator(value: score / 100, strokeWidth: 10, backgroundColor: Colors.white10, color: _getScoreColor())),
            Text("${score.toInt()}%", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _getScoreColor())),
          ]),
          const SizedBox(height: 30),
          _skillDisplay("MATCHED SKILLS", found, Colors.greenAccent),
          const SizedBox(height: 20),
          _skillDisplay("SKILL GAPS", missing, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _styledTextField(TextEditingController controller, String hint, bool isLarge) {
    return TextField(
      controller: controller,
      // Setting expands: true forces the text field to take up all available vertical space
      expands: isLarge,
      maxLines: isLarge ? null : 1,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
      ),
    );
  }

  Widget _skillDisplay(String title, List items, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(10)),
        child: items.isEmpty
            ? const Text("None", style: TextStyle(color: Colors.white24, fontSize: 12))
            : Wrap(
          spacing: 6, runSpacing: 6,
          children: items.map((i) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))), child: Text(i, style: TextStyle(fontSize: 10, color: color)))).toList(),
        ),
      ),
    ]);
  }

  Color _getScoreColor() {
    if (score < 40) return Colors.redAccent;
    if (score < 75) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
}
