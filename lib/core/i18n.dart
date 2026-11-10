import 'i18n_data.dart';

/// Ағымдағы тіл: 'kk' | 'ru' | 'en'
String gLang = 'kk';

/// Қазақша мәтінді ағымдағы тілге аудару (ескі t() функциясымен бірдей).
String t(String s) {
  if (gLang == 'kk') return s;
  final r = kI18n[s];
  if (r == null) return s;
  final v = gLang == 'ru' ? r[0] : r[1];
  return v.isEmpty ? s : v;
}

const kMonths = ['Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым', 'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'];
const kMonShort = ['қаң', 'ақп', 'нау', 'сәу', 'мам', 'мау', 'шіл', 'там', 'қыр', 'қаз', 'қар', 'жел'];
/// Жексенбіден басталады (JS getDay() сияқты: 0 = жексенбі)
const kWdays = ['Жексенбі', 'Дүйсенбі', 'Сейсенбі', 'Сәрсенбі', 'Бейсенбі', 'Жұма', 'Сенбі'];
const kWdShort = ['Жс', 'Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб'];

String monName(int i) => t(kMonths[i]);
String monShort(int i) => t(kMonShort[i]);
