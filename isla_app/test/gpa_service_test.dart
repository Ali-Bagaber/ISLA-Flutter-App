/// Unit tests for the GPA / CGPA math in GpaService.
///
/// Pure-function tests — no Firebase, no Flutter widgets, runs anywhere.
import 'package:flutter_test/flutter_test.dart';
import 'package:isla_app/services/gpa_service.dart';

void main() {
  group('GpaService.computeGpa', () {
    test('returns 0.0 for an empty course list', () {
      expect(GpaService.computeGpa([]), 0.0);
    });

    test('returns 4.0 for a single A grade', () {
      expect(
        GpaService.computeGpa([
          {'name': 'Math', 'credits': 3, 'grade': 'A'},
        ]),
        4.0,
      );
    });

    test('returns the credit-weighted average across courses', () {
      // 3 credit A (4.0) + 3 credit B (3.0)  →  (12 + 9) / 6 = 3.5
      expect(
        GpaService.computeGpa([
          {'name': 'CS', 'credits': 3, 'grade': 'A'},
          {'name': 'Math', 'credits': 3, 'grade': 'B'},
        ]),
        3.5,
      );
    });

    test('ignores courses with unknown grades', () {
      expect(
        GpaService.computeGpa([
          {'name': 'Math', 'credits': 3, 'grade': 'A'},
          {'name': 'Weird', 'credits': 3, 'grade': 'XYZ'},
        ]),
        4.0,
      );
    });
  });

  group('GpaService.computeCgpa', () {
    test('returns 0.0 for empty semesters', () {
      expect(GpaService.computeCgpa([]), 0.0);
    });

    test('matches computeGpa for one semester', () {
      final semesters = [
        {
          'id': 'sem1',
          'name': 'Semester 1',
          'courses': [
            {'credits': 3, 'grade': 'A'},
            {'credits': 3, 'grade': 'B'},
          ],
        },
      ];
      expect(GpaService.computeCgpa(semesters), 3.5);
    });

    test('weights by total credits across semesters', () {
      // Sem1: 2x3cr A = 8cr @ 4.0 = 24 pts
      // Sem2: 1x3cr C = 3cr @ 2.0 = 6 pts
      // CGPA = (24 + 6) / 9 = 3.33
      final semesters = [
        {
          'name': 'Sem 1',
          'courses': [
            {'credits': 3, 'grade': 'A'},
            {'credits': 3, 'grade': 'A'},
          ],
        },
        {
          'name': 'Sem 2',
          'courses': [
            {'credits': 3, 'grade': 'C'},
          ],
        },
      ];
      expect(GpaService.computeCgpa(semesters), 3.33);
    });
  });

  group('GpaService.computeTotalCredits', () {
    test('sums credits across all semesters', () {
      final semesters = [
        {
          'courses': [
            {'credits': 3},
            {'credits': 4},
          ],
        },
        {
          'courses': [
            {'credits': 2},
          ],
        },
      ];
      expect(GpaService.computeTotalCredits(semesters), 9);
    });
  });
}
