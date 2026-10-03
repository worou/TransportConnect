import 'package:intl/intl.dart';

final _fcfa = NumberFormat.decimalPattern('fr_FR');
final _date = DateFormat('dd/MM/yyyy', 'fr_FR');
final _dateHeure = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

/// 45000 → « 45 000 F »
String fcfa(Object? montant) => montant == null ? '—' : '${_fcfa.format(num.parse('$montant'))} F';

/// 12 500 000 → « 12,5 MF »
String fcfaCompact(num montant) =>
    montant >= 1000000 ? '${NumberFormat('#,##0.#', 'fr_FR').format(montant / 1000000)} MF' : fcfa(montant);

String date(Object? iso) => iso == null ? '—' : _date.format(DateTime.parse('$iso').toLocal());

String dateHeure(Object? iso) => iso == null ? '—' : _dateHeure.format(DateTime.parse('$iso').toLocal());

String nombre(num n) => _fcfa.format(n);
