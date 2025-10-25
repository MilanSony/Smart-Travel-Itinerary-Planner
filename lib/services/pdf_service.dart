import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/itinerary_model.dart';

class PdfService {
  static Future<bool> exportItineraryToPdf(Itinerary itinerary) async {
    try {
      print('Starting PDF generation for: ${itinerary.destination}');
      
      // Generate PDF document
      final pdf = await _generateSimplePdf(itinerary);
      print('PDF document generated successfully');
      
      // Try to save to file first, then show print dialog
      try {
        // Save to file
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
        final file = File('${directory.path}/$fileName');
        
        final bytes = await pdf.save();
        await file.writeAsBytes(bytes);
        print('PDF saved to: ${file.path}');
        
        // Show print dialog
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async {
            return bytes;
          },
          name: fileName,
        );
        
        print('PDF export completed successfully');
        return true;
      } catch (printError) {
        print('Print dialog failed, trying direct file access: $printError');
        
        // Fallback: just save the file and show success message
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
        final file = File('${directory.path}/$fileName');
        
        final bytes = await pdf.save();
        await file.writeAsBytes(bytes);
        print('PDF saved to: ${file.path}');
        
        return true;
      }
    } catch (e) {
      print('Error generating PDF: $e');
      print('Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Simple PDF generation as fallback
  static Future<pw.Document> _generateSimplePdf(Itinerary itinerary) async {
    final pdf = pw.Document();

    // Add cover page with trip summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Trip Itinerary',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Destination: ${itinerary.destination}',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.black),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Duration: ${itinerary.dayPlans.length} days',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.black),
                ),
                if (itinerary.totalEstimatedCost != null) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Total Cost: ₹${itinerary.totalEstimatedCost!.toStringAsFixed(0)}',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.black),
                  ),
                ],
                pw.SizedBox(height: 30),
                pw.Text(
                  'Trip Overview',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'This itinerary includes ${itinerary.dayPlans.length} days of activities, meals, and transportation. Each day is detailed on the following pages.',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.black),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add a separate page for each day
    for (int i = 0; i < itinerary.dayPlans.length; i++) {
      final dayPlan = itinerary.dayPlans[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Day header
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue800,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      'Day ${i + 1} - ${dayPlan.dayTitle}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Day description if available
                  if (dayPlan.description.isNotEmpty) ...[
                    pw.Text(
                      'Description',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      dayPlan.description,
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                  
                  // Activities
                  pw.Text(
                    'Activities',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  
                  // List all activities for this day
                  ...dayPlan.activities.map((activity) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 15),
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                activity.time,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800,
                                ),
                              ),
                              pw.SizedBox(width: 10),
                              pw.Expanded(
                                child: pw.Text(
                                  activity.title,
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            activity.description,
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.black,
                            ),
                          ),
                          if (activity.cost != null) ...[
                            pw.SizedBox(height: 8),
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Cost: ',
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  activity.cost!,
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.green800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  
                  // Day cost summary if available
                  if (dayPlan.totalEstimatedCost != null) ...[
                    pw.SizedBox(height: 20),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Day ${i + 1} Total Cost:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '₹${dayPlan.totalEstimatedCost!.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf;
  }

  static Future<pw.Document> _generateItineraryPdf(Itinerary itinerary) async {
    try {
      final pdf = pw.Document();

      // Add cover page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildCoverPage(itinerary);
          },
        ),
      );

      // Add summary page
      if (itinerary.summary != null || itinerary.totalEstimatedCost != null) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildSummaryPage(itinerary);
            },
          ),
        );
      }

      // Add day-wise itinerary pages
      for (int i = 0; i < itinerary.dayPlans.length; i++) {
        final dayPlan = itinerary.dayPlans[i];
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return _buildDayPlanPage(dayPlan, i + 1);
            },
          ),
        );
      }

      return pdf;
    } catch (e) {
      print('Error in _generateItineraryPdf: $e');
      rethrow;
    }
  }

  static pw.Widget _buildCoverPage(Itinerary itinerary) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColors.blue800,
            PdfColors.purple800,
          ],
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(40),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Trip Genie',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Your Adventure in',
              style: pw.TextStyle(
                fontSize: 18,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              itinerary.destination,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${itinerary.dayPlans.length} Days',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  if (itinerary.totalEstimatedCost != null)
                    pw.Text(
                      'Estimated Cost: ₹${itinerary.totalEstimatedCost!.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Generated by Trip Genie',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryPage(Itinerary itinerary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Trip Summary',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 20),
          if (itinerary.summary != null) ...[
            pw.Text(
              itinerary.summary!,
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 20),
          ],
          if (itinerary.totalEstimatedCost != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Total Estimated Cost: ',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₹${itinerary.totalEstimatedCost!.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Day-wise Budget Breakdown',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 10),
            ...itinerary.dayPlans.asMap().entries.map((entry) {
              final index = entry.key;
              final dayPlan = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Day ${index + 1}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₹${dayPlan.totalEstimatedCost?.toStringAsFixed(0) ?? '0'}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildDayPlanPage(DayPlan dayPlan, int dayNumber) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  dayPlan.dayTitle,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Spacer(),
                if (dayPlan.totalEstimatedCost != null)
                  pw.Text(
                    '₹${dayPlan.totalEstimatedCost!.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (dayPlan.description.isNotEmpty) ...[
            pw.Text(
              'Description',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              dayPlan.description,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 20),
          ],
          pw.Text(
            'Activities',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 15),
          ...dayPlan.activities.map((activity) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 15),
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        activity.time,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Spacer(),
                      if (activity.estimatedDuration != null)
                        pw.Text(
                          activity.estimatedDuration!,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    activity.title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    activity.description,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.black,
                    ),
                  ),
                  if (activity.cost != null) ...[
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Cost: ',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          activity.cost!,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  static Future<String?> getDownloadedPdfPath(Itinerary itinerary) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      print('Error getting PDF path: $e');
      return null;
    }
  }

  static Future<bool> deleteDownloadedPdf(Itinerary itinerary) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting PDF: $e');
      return false;
    }
  }

  static Future<bool> isPdfAvailable(Itinerary itinerary) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
      final file = File('${directory.path}/$fileName');
      return await file.exists();
    } catch (e) {
      print('Error checking PDF availability: $e');
      return false;
    }
  }

  static Future<String?> getPdfPath(Itinerary itinerary) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${itinerary.destination.replaceAll(' ', '_')}_itinerary.pdf';
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      print('Error getting PDF path: $e');
      return null;
    }
  }
}
