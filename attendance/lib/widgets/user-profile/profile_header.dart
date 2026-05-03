import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileHeader extends StatelessWidget {
  final Employee employee;

  const ProfileHeader({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Build your banner here
            Container(
              height: 150,
              width: double.infinity,
              color: const Color.fromARGB(255, 3, 37, 61),
            ),

            // 2. Build your Positioned CircleAvatar here
            Positioned(
              bottom: -50,
              child: CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  // User-image
                  backgroundImage: employee.avatarUrl != null
                      ? NetworkImage(employee.avatarUrl!)
                      : null,
                  child: employee.avatarUrl == null
                      ? const Icon(
                          Icons.person_2_rounded,
                          size: 50,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 60),

        //User-Details texts
        Text(
          employee.name,
          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),

        //USers-Subdetails texts
        Text(
          '${employee.department} . ${employee.id}',
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.normal,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
