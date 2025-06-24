import 'dart:async';
import 'dart:io';
import 'dart:convert'; // Required for JSON encoding/decoding

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:http/http.dart' as http; // Required for making HTTP requests
import 'package:html/parser.dart' show parse; // Required for parsing HTML
import 'package:html/dom.dart'; // Required for DOM Element type

/// Function to search for specific text within a designated section of a website's HTML.
///
/// [url]: The URL of the website to fetch HTML from.
/// [searchText]: The specific text to search for (e.g., "Electrical Power System").
/// [sectionIdentifier]: The text that identifies the desired section (e.g., "Winter 2024").
/// [context]: The Appwrite function context for logging.
///
/// Returns a map with 'found' (boolean) and 'message' (string) indicating the result.
Future<Map<String, dynamic>> searchTextInWebsiteHtml(
  String url,
  String searchText,
  String sectionIdentifier,
  final context,
) async {
  try {
    // 1. Fetch the HTML content from the given URL
    final response = await http.get(Uri.parse(url));

    // Check if the request was successful (status code 200)
    if (response.statusCode == 200) {
      // 2. Parse the HTML content
      final Document document = parse(response.body);

      String sectionContent = '';
      bool sectionFound = false;

      // 3. Iterate through all elements to find the section identifier
      for (final element in document.querySelectorAll('*')) {
        if (element.text.toLowerCase().contains(sectionIdentifier.toLowerCase())) {
          sectionContent = element.text;
          sectionFound = true;
          context.log('Found section: "$sectionIdentifier". Extracting content for further search.');
          break;
        }
      }

      if (!sectionFound) {
        context.log('Section "$sectionIdentifier" not found on the page.');
        return {'found': false, 'message': 'Section "$sectionIdentifier" not found on the page.'};
      }

      // 4. Search for the specified text within the content of the identified section
      if (sectionContent.toLowerCase().contains(searchText.toLowerCase())) {
        context.log('Found "$searchText" within the "$sectionIdentifier" section.');
        return {'found': true, 'message': 'Text "$searchText" found within section "$sectionIdentifier".'};
      } else {
        context.log('"$searchText" not found within the "$sectionIdentifier" section.');
        return {'found': false, 'message': 'Text "$searchText" not found within section "$sectionIdentifier".'};
      }
    } else {
      context.error('Failed to load page: ${response.statusCode}. Status: ${response.statusCode}');
      return {'found': false, 'message': 'Failed to load page: HTTP status ${response.statusCode}.'};
    }
  } catch (e) {
    context.error('An error occurred during searchTextInWebsiteHtml: $e');
    return {'found': false, 'message': 'An error occurred: $e'};
  }
}

/// A standalone function to find specific <a> tags within a <div> identified by its ID.
///
/// [url]: The URL of the website to fetch HTML from.
/// [divId]: The ID of the <div> element to search within (e.g., "v-pills-all-1").
/// [linkTextToFind]: The partial or exact text content of the <a> tags to find (e.g., "Fifth Semester").
/// [context]: The Appwrite function context for logging.
///
/// Returns a list of maps, where each map contains 'text' and 'href' of the found links.
/// Returns an empty list if no matching links are found, or an error occurs.
Future<List<Map<String, String>>> findSpecificLinksInDiv(
  String url,
  String divId,
  String linkTextToFind,
  final context,
) async {
  try {
    // 1. Fetch the HTML content from the given URL
    final response = await http.get(Uri.parse(url));

    // Check if the request was successful (status code 200)
    if (response.statusCode == 200) {
      // 2. Parse the HTML content
      final Document document = parse(response.body);

      // 3. Find the div element by its ID
      final Element? targetDiv = document.getElementById(divId);

      if (targetDiv == null) {
        context.log('Div with ID "$divId" not found on the page.');
        return []; // Return empty list if div not found
      }

      // 4. Find all <a> tags within the target div
      final List<Element> allAnchorTagsInDiv = targetDiv.querySelectorAll('a');

      // 5. Filter the <a> tags based on their text content (now supporting partial match)
      final List<Map<String, String>> matchingLinks = allAnchorTagsInDiv.where((anchor) {
        // Trim whitespace from anchor text and convert both to lowercase for case-insensitive partial matching
        return anchor.text.trim().toLowerCase().contains(linkTextToFind.toLowerCase());
      }).map((anchor) {
        return {
          'text': anchor.text.trim(),
          'href': anchor.attributes['href'] ?? 'N/A', // Use 'N/A' if href is missing
        };
      }).toList();

      if (matchingLinks.isEmpty) {
        context.log('No <a> tags with text containing "$linkTextToFind" found inside div "$divId".');
      } else {
        context.log('Found ${matchingLinks.length} matching <a> tags inside div "$divId".');
      }

      return matchingLinks;
    } else {
      context.error('Failed to load page: ${response.statusCode}. Status: ${response.statusCode}');
      return []; // Return empty list on HTTP error
    }
  } catch (e) {
    context.error('An error occurred during findSpecificLinksInDiv: $e');
    return []; // Return empty list on general error
  }
}

// This Appwrite function will be executed every time your function is triggered
Future<dynamic> main(final context) async {
  // Initialize Appwrite Client (optional for this specific use case, but kept from template)
  final client = Client()
      .setEndpoint(Platform.environment['APPWRITE_FUNCTION_API_ENDPOINT'] ?? '')
      .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'] ?? '')
      .setKey(context.req.headers['x-appwrite-key'] ?? '');

  // Example of using Appwrite Users service (kept from template, can be removed if not needed)
  final users = Users(client);
  try {
    final response = await users.list();
    context.log('Total users: ' + response.total.toString());
  } catch (e) {
    context.error('Could not list users: ' + e.toString());
  }

  // Handle /ping request as per original template
  if (context.req.path == "/ping") {
    return context.res.text('Pong');
  }

  // Handle /result endpoint with GET request
  if (context.req.path == "/result" && context.req.method == "GET") {
    // Extract parameters from query parameters for GET requests
    final String url = context.req.query['url'] ?? '';
    final String searchText = context.req.query['searchText'] ?? '';
    final String sectionIdentifier = context.req.query['sectionIdentifier'] ?? '';
    final String divId = context.req.query['divId'] ?? '';
    final String linkTextToFind = context.req.query['linkTextToFind'] ?? '';

    // Validate essential URL parameter
    if (url.isEmpty) {
      context.error('URL query parameter is missing or empty for /result GET request.');
      return context.res.json({
        'status': 'error',
        'message': 'The "url" query parameter is required for the /result endpoint.',
      }, 400); // Bad Request
    }

    Map<String, dynamic> searchTextResult = {};
    List<Map<String, String>> findLinksResult = [];

    // --- Execute searchTextInWebsiteHtml if searchText and sectionIdentifier are provided ---
    if (searchText.isNotEmpty && sectionIdentifier.isNotEmpty) {
      searchTextResult = await searchTextInWebsiteHtml(url, searchText, sectionIdentifier, context);
    } else {
      searchTextResult = {'found': false, 'message': 'Skipped search: searchText or sectionIdentifier not provided.'};
      context.log('Skipping searchTextInWebsiteHtml as searchText or sectionIdentifier were not provided.');
    }

    // --- Execute findSpecificLinksInDiv if divId and linkTextToFind are provided ---
    if (divId.isNotEmpty && linkTextToFind.isNotEmpty) {
      findLinksResult = await findSpecificLinksInDiv(url, divId, linkTextToFind, context);
    } else {
      findLinksResult = []; // Empty list
      context.log('Skipping findSpecificLinksInDiv as divId or linkTextToFind were not provided.');
    }

    // Construct the final JSON response for /result
    return context.res.json({
      'status': 'success',
      'url': url,
      'searchTextInWebsiteHtml': searchTextResult,
      'findSpecificLinksInDiv': {
        'linksFound': findLinksResult,
        'message': findLinksResult.isNotEmpty
            ? 'Found ${findLinksResult.length} link(s) matching the criteria.'
            : 'No links found matching the criteria.',
      },
    });
  }

  // Default response if no specific path/method matches (e.g., if you later add POST to /result or other paths)
  // This part of the code will only be reached if the request is NOT /ping and NOT /result (GET)
  return context.res.json({
    'status': 'info',
    'message': 'Please use GET /result with query parameters or POST to a different endpoint if supported.',
    'motto': 'Build like a team of hundreds_',
    'learn': 'https://appwrite.io/docs',
    'connect': 'https://appwrite.io/discord',
    'getInspired': 'https://builtwith.appwrite.io',
  });
}
