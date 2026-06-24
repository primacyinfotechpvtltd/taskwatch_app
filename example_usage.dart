// Example usage of OdooNetworkImage with the new directImageUrl feature

import 'package:flutter/material.dart';
import 'lib/widgets/odoo_network_image.dart';

class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OdooNetworkImage Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Example 1: Using direct URL ONLY (NEW FEATURE)
            const Text(
              '1. Using Direct URL Only (No model/id needed):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OdooNetworkImage(
              directImageUrl:
                  'http://192.168.1.17:8017/web/image/hr.employee/2/image_128',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),

            const SizedBox(height: 24),

            // Example 2: Using direct URL with different field (No model/id needed)
            const Text(
              '2. Using Direct URL with image_512 (No model/id needed):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OdooNetworkImage(
              directImageUrl:
                  'http://192.168.1.17:8017/web/image/hr.employee/2/image_512',
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),

            const SizedBox(height: 24),

            // Example 3: Using direct URL with different model (No model/id needed)
            const Text(
              '3. Using Direct URL with res.partner (No model/id needed):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OdooNetworkImage(
              directImageUrl:
                  'http://192.168.1.17:8017/web/image/res.partner/1/image_128',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              placeholder: const CircularProgressIndicator(),
              errorWidget: const Icon(Icons.person, size: 50),
            ),

            const SizedBox(height: 24),

            // Example 4: Using direct URL with backward compatibility (optional model/id)
            const Text(
              '4. Using Direct URL with Optional model/id:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OdooNetworkImage(
              model: 'hr.employee', // Optional when using directImageUrl
              id: 2, // Optional when using directImageUrl
              directImageUrl:
                  'http://192.168.1.17:8017/web/image/hr.employee/2/image_128',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),

            const SizedBox(height: 24),

            // Example 5: Fallback to dynamic URL generation (model/id required)
            const Text(
              '5. Dynamic URL Generation (model/id required):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const OdooNetworkImage(
              model: 'hr.employee',
              id: 3,
              field: 'image_128',
              width: 100,
              height: 100,
            ),

            const SizedBox(height: 24),

            // Example 6: Using base64 data (no model/id needed)
            const Text(
              '6. Using Base64 Data (no model/id needed):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OdooNetworkImage(
              base64Data:
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
              width: 100,
              height: 100,
            ),
          ],
        ),
      ),
    );
  }
}

// Usage Notes:
//
// 1. Priority Order:
//    - If 'base64Data' is provided, it takes highest priority
//    - If 'directImageUrl' is provided, it takes second priority
//    - Otherwise, dynamic URL generation is used (requires model and id)
//
// 2. Parameter Requirements:
//    - When using 'directImageUrl': NO need to pass model and id
//    - When using 'base64Data': NO need to pass model and id
//    - When using dynamic URL generation: model and id are REQUIRED
//    - The widget uses assertions to enforce these requirements
//
// 3. Authentication:
//    - Direct URLs may or may not require authentication headers
//    - The widget automatically detects if the URL contains '/web/image' and adds session headers if available
//    - For URLs that don't contain '/web/image', no authentication headers are added
//
// 4. Simplified Usage Examples:
//    
//    // Just direct URL - SIMPLEST way
//    OdooNetworkImage(
//      directImageUrl: 'http://192.168.1.17:8017/web/image/hr.employee/2/image_128',
//      width: 100,
//      height: 100,
//    )
//    
//    // Just base64 data
//    OdooNetworkImage(
//      base64Data: 'your_base64_string_here',
//      width: 100,
//      height: 100,
//    )
//    
//    // Dynamic URL (requires model and id)
//    OdooNetworkImage(
//      model: 'hr.employee',
//      id: 2,
//      field: 'image_128', // optional, defaults to 'image_128'
//      width: 100,
//      height: 100,
//    )
//
// 5. Error Handling:
//    - The widget gracefully handles network errors, invalid URLs, and missing images
//    - Custom error widgets can be provided via the 'errorWidget' parameter
//    - Assertion errors will be thrown if neither directImageUrl nor (model+id) are provided
//
// 6. Performance:
//    - Direct URLs are the most efficient as they skip all authentication and URL generation logic
//    - Base64 data is also efficient as it doesn't require network requests
//    - Dynamic URL generation is useful when you need to integrate with existing Odoo authentication
