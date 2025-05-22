import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // For TapGestureRecognizer
import 'package:url_launcher/url_launcher.dart'; // For opening links

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  // Helper to create a TextSpan with a link
  TextSpan _buildLinkTextSpan(String text, String url) {
    return TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.blue, // Link color
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final Uri uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            // Handle error: could not launch url
            // In a real app, consider showing a SnackBar or other user feedback
            print('Could not launch $url');
          }
        },
    );
  }

  // Helper widget for information sections
  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...children, // Add children below the title
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Placeholders for email and links (replace with actual values)
    const String netraiEmail = 'netraiteam01@gmail.com';
    const String googleFormUrl = 'https://forms.gle/your-form-link'; // Replace link
    const String waLink = 'https://wa.me/yourphonenumber'; // Replace WA link

    final TextStyle bodyTextStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: 'Inter',
      color: Colors.black.withOpacity(0.8),
      height: 1.3, // Line height
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: Image.asset(
            // Use PNG back arrow
            'assets/images/arrow_back.png',
            height: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Contact Us',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoSection(
            title: 'Need Help or Have Feedback?',
            children: [
              Text(
                'We\'re here to support you. If you have questions, face any issues, or want to share feedback about NetrAI, please reach out. Our team is happy to help you live more independently with confidence.',
                style: bodyTextStyle,
              ),
            ],
          ),
          _buildInfoSection(
            title: 'Ways to Contact Us:',
            children: [
              Text.rich(
                TextSpan(
                  style: bodyTextStyle,
                  children: <TextSpan>[
                    const TextSpan(text: 'Email: Reach out anytime at: '),
                    _buildLinkTextSpan(netraiEmail, 'mailto:$netraiEmail'),
                    const TextSpan(
                      text: '\n(We\'ll reply within 1-2 business days)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: bodyTextStyle,
                  children: <TextSpan>[
                    const TextSpan(
                      text:
                          'Feedback Form: Got suggestions or bug reports? Fill out our short form \n',
                    ),
                    _buildLinkTextSpan(
                      'Click here for accessing the Google Form Link',
                      googleFormUrl,
                    ),
                    const TextSpan(
                      text: '\nor freely send us voice notes via WA chat:\n',
                    ),
                    _buildLinkTextSpan(
                      'Click here for send us WA voice note',
                      waLink,
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildInfoSection(
            title: 'Support Hours:',
            children: [
              Text(
                'Monday to Friday\n9:00 AM - 5:00 PM (WIB / GMT+7)',
                style: bodyTextStyle,
              ),
              const SizedBox(height: 4),
              Text(
                'Support available in Bahasa Indonesia and English', // This was already in English
                style: bodyTextStyle,
              ),
            ],
          ),
          _buildInfoSection(
            title: 'Reminder:',
            children: [
              Text(
                'NetrAI is here to help guide and inform — but it is not a replacement for mobility devices. Please continue using your cane, guide dog, or other tools for safe physical navigation.',
                style: bodyTextStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
