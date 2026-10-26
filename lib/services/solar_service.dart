import 'dart:math' as math;

/// Cidade brasileira com coordenadas e fuso horário para cálculo solar
class SolarCity {
  final String name;
  final String state;
  final double latitude;
  final double longitude;
  final double timezoneOffset; // ex: -3.0 para Brasília

  const SolarCity({
    required this.name,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.timezoneOffset = -3.0,
  });

  String get displayName => '$name - $state';
}

/// Serviço autônomo offline para cálculo astronômico solar usando o algoritmo NOAA
/// (National Oceanic and Atmospheric Administration).
class SolarService {
  SolarService._();

  /// Capitais e cidades principais de referência no Brasil (padrão: Brasília)
  static const SolarCity defaultCity = SolarCity(
    name: 'Brasília',
    state: 'DF',
    latitude: -15.793889,
    longitude: -47.882778,
    timezoneOffset: -3.0,
  );

  static const List<SolarCity> predefinedCities = [
    SolarCity(name: 'Brasília', state: 'DF', latitude: -15.793889, longitude: -47.882778, timezoneOffset: -3.0),
    SolarCity(name: 'São Paulo', state: 'SP', latitude: -23.550520, longitude: -46.633308, timezoneOffset: -3.0),
    SolarCity(name: 'Rio de Janeiro', state: 'RJ', latitude: -22.906847, longitude: -43.172896, timezoneOffset: -3.0),
    SolarCity(name: 'Belo Horizonte', state: 'MG', latitude: -19.916681, longitude: -43.934493, timezoneOffset: -3.0),
    SolarCity(name: 'Salvador', state: 'BA', latitude: -12.971399, longitude: -38.501550, timezoneOffset: -3.0),
    SolarCity(name: 'Fortaleza', state: 'CE', latitude: -3.731862, longitude: -38.526672, timezoneOffset: -3.0),
    SolarCity(name: 'Curitiba', state: 'PR', latitude: -25.428954, longitude: -49.267137, timezoneOffset: -3.0),
    SolarCity(name: 'Recife', state: 'PE', latitude: -8.047562, longitude: -34.876964, timezoneOffset: -3.0),
    SolarCity(name: 'Porto Alegre', state: 'RS', latitude: -30.034647, longitude: -51.217658, timezoneOffset: -3.0),
    SolarCity(name: 'Manaus', state: 'AM', latitude: -3.119028, longitude: -60.021731, timezoneOffset: -4.0),
    SolarCity(name: 'Belém', state: 'PA', latitude: -1.455755, longitude: -48.490180, timezoneOffset: -3.0),
    SolarCity(name: 'Goiânia', state: 'GO', latitude: -16.686891, longitude: -49.264794, timezoneOffset: -3.0),
    SolarCity(name: 'São Luís', state: 'MA', latitude: -2.539110, longitude: -44.282900, timezoneOffset: -3.0),
    SolarCity(name: 'Cuiabá', state: 'MT', latitude: -15.601411, longitude: -56.097893, timezoneOffset: -4.0),
    SolarCity(name: 'Campo Grande', state: 'MS', latitude: -20.469711, longitude: -54.620121, timezoneOffset: -4.0),
    SolarCity(name: 'Natal', state: 'RN', latitude: -5.794480, longitude: -35.211000, timezoneOffset: -3.0),
    SolarCity(name: 'João Pessoa', state: 'PB', latitude: -7.119496, longitude: -34.845012, timezoneOffset: -3.0),
    SolarCity(name: 'Maceió', state: 'AL', latitude: -9.665800, longitude: -35.735100, timezoneOffset: -3.0),
    SolarCity(name: 'Teresina', state: 'PI', latitude: -5.091940, longitude: -42.803400, timezoneOffset: -3.0),
    SolarCity(name: 'Florianópolis', state: 'SC', latitude: -27.595378, longitude: -48.548050, timezoneOffset: -3.0),
    SolarCity(name: 'Aracaju', state: 'SE', latitude: -10.947200, longitude: -37.073100, timezoneOffset: -3.0),
    SolarCity(name: 'Porto Velho', state: 'RO', latitude: -8.761160, longitude: -63.903900, timezoneOffset: -4.0),
    SolarCity(name: 'Rio Branco', state: 'AC', latitude: -9.974990, longitude: -67.824300, timezoneOffset: -5.0),
    SolarCity(name: 'Boa Vista', state: 'RR', latitude: 2.823840, longitude: -60.675800, timezoneOffset: -4.0),
    SolarCity(name: 'Macapá', state: 'AP', latitude: 0.035570, longitude: -51.070500, timezoneOffset: -3.0),
    SolarCity(name: 'Palmas', state: 'TO', latitude: -10.184400, longitude: -48.333600, timezoneOffset: -3.0),
    SolarCity(name: 'Vitória', state: 'ES', latitude: -20.315500, longitude: -40.312800, timezoneOffset: -3.0),
  ];

  /// Calcula o DateTime exato do Pôr do Sol para a data e cidade dadas usando o modelo NOAA
  static DateTime? calculateSunset({
    required DateTime date,
    required double latitude,
    required double longitude,
    double timezoneOffset = -3.0,
  }) {
    // 1. Dia do ano (1 a 366)
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;

    // 2. Fração do ano em radianos (gamma)
    final gamma = (2 * math.pi / 365.0) * (dayOfYear - 1 + (12 - 12) / 24.0);

    // 3. Equação do tempo (em minutos)
    final eqtime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    // 4. Declinação solar (em radianos)
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    // 5. Ângulo horário do pôr do sol (zenith padrão NOAA de 90.833° = 90° 50')
    const zenith = 90.833 * (math.pi / 180.0);
    final latRad = latitude * (math.pi / 180.0);

    final cosHa = (math.cos(zenith) / (math.cos(latRad) * math.cos(decl))) -
        (math.tan(latRad) * math.tan(decl));

    if (cosHa > 1.0 || cosHa < -1.0) {
      // Dia polar ou noite polar (não aplicável à maior parte do globo)
      return null;
    }

    final haRad = math.acos(cosHa);
    final haDeg = haRad * (180.0 / math.pi);

    // 6. Horário do pôr do sol em minutos a partir da meia-noite UTC
    final sunsetMinutesUtc = 720.0 - (4.0 * longitude) - eqtime + (4.0 * haDeg);

    // Converte para minutos no fuso local
    final localMinutes = sunsetMinutesUtc + (timezoneOffset * 60.0);

    var totalMinutes = localMinutes.round();
    while (totalMinutes < 0) {
      totalMinutes += 24 * 60;
    }
    while (totalMinutes >= 24 * 60) {
      totalMinutes -= 24 * 60;
    }

    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Próxima sexta-feira relativa à data informada
  static DateTime getNextFriday(DateTime from) {
    var d = DateTime(from.year, from.month, from.day);
    while (d.weekday != DateTime.friday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Retorna o pôr do sol da sexta-feira desta semana (ou de hoje, se hoje for sexta)
  static DateTime getFridaySunset({
    DateTime? referenceDate,
    SolarCity city = defaultCity,
  }) {
    final now = referenceDate ?? DateTime.now();
    DateTime targetFriday;
    if (now.weekday == DateTime.friday) {
      targetFriday = DateTime(now.year, now.month, now.day);
    } else {
      targetFriday = getNextFriday(now);
    }

    final sunset = calculateSunset(
      date: targetFriday,
      latitude: city.latitude,
      longitude: city.longitude,
      timezoneOffset: city.timezoneOffset,
    );

    return sunset ?? DateTime(targetFriday.year, targetFriday.month, targetFriday.day, 18, 0);
  }

  /// Formata um DateTime no formato HH:mm
  static String formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

