import 'package:intl/intl.dart';

String formatDate(int epochMs) =>
    DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

String formatHeure(int epochMs) =>
    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

String formatDateHeure(int epochMs) => '${formatDate(epochMs)} ${formatHeure(epochMs)}';
