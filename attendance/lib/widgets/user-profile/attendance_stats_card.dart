import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendanceStatsCard extends StatelessWidget {
  final Employee employee;
  const AttendanceStatsCard({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.rectangle,
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5), // Shadow color
            spreadRadius: 5, // How much the shadow spreads
            blurRadius: 7, // Softness of the shadow
            offset: Offset(0, 3),
          ),
        ],
      ),

      //Row
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.totalPresents}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Total Presents',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w100,
                        color: Colors.grey[100],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 20, color: Colors.blueGrey[200]),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.totalAbsents}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Total Absents',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w100,
                        color: Colors.grey[100],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(width: 20, color: Colors.blueGrey[200]),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      '${employee.totalLeaves}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white38,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Total Leaves',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w100,
                        color: Colors.grey[100],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
