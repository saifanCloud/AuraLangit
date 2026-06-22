// test/widget_test.dart
//
// Unit & widget tests untuk aplikasi What-Her Weather.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:weather_app/weather_service.dart';
import 'package:weather_app/splash_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('WeatherService Unit Tests', () {
    test('CurrentWeather.fromJson parses JSON correctly', () {
      final json = {
        'main': {
          'temp': 28.5,
          'feels_like': 30.2,
          'temp_min': 25.0,
          'temp_max': 31.0,
          'humidity': 80,
        },
        'weather': [
          {
            'main': 'Rain',
            'description': 'hujan sedang',
            'icon': '10d',
          }
        ],
        'wind': {
          'speed': 5.5,
        },
        'visibility': 8000,
        'coord': {
          'lat': -6.2088,
          'lon': 106.8456,
        },
        'name': 'Jakarta',
      };

      final weather = CurrentWeather.fromJson(json, 'Jakarta');

      expect(weather.cityName, 'Jakarta');
      expect(weather.temperature, 28.5);
      expect(weather.feelsLike, 30.2);
      expect(weather.tempMin, 25.0);
      expect(weather.tempMax, 31.0);
      expect(weather.weatherMain, 'Rain');
      expect(weather.weatherDescription, 'hujan sedang');
      expect(weather.weatherIcon, '10d');
      expect(weather.humidity, 80);
      expect(weather.windSpeed, 5.5);
      expect(weather.visibility, 8000);
      expect(weather.lat, -6.2088);
      expect(weather.lon, 106.8456);
    });

    test('getWeatherEmoji returns correct emoji', () {
      expect(WeatherService.getWeatherEmoji('Clear'), '☀️');
      expect(WeatherService.getWeatherEmoji('Clouds'), '☁️');
      expect(WeatherService.getWeatherEmoji('Rain'), '🌧️');
      expect(WeatherService.getWeatherEmoji('Drizzle'), '🌦️');
      expect(WeatherService.getWeatherEmoji('Thunderstorm'), '⛈️');
      expect(WeatherService.getWeatherEmoji('Snow'), '❄️');
      expect(WeatherService.getWeatherEmoji('Mist'), '🌫️');
      expect(WeatherService.getWeatherEmoji('Unknown'), '🌤️');
    });

    test('getWeatherIconName returns correct icon name', () {
      expect(WeatherService.getWeatherIconName('Clear'), 'wb_sunny');
      expect(WeatherService.getWeatherIconName('Clouds'), 'cloud');
      expect(WeatherService.getWeatherIconName('Rain'), 'umbrella');
      expect(WeatherService.getWeatherIconName('Drizzle'), 'grain');
      expect(WeatherService.getWeatherIconName('Thunderstorm'), 'thunderstorm');
      expect(WeatherService.getWeatherIconName('Snow'), 'ac_unit');
      expect(WeatherService.getWeatherIconName('Unknown'), 'wb_cloudy');
    });

    test('getIconUrl returns correct URL', () {
      expect(
        WeatherService.getIconUrl('10d'),
        'https://openweathermap.org/img/wn/10d@2x.png',
      );
    });
  });

  group('Widget Tests', () {
    testWidgets('SplashScreen renders app name', (WidgetTester tester) async {
      // Menggunakan runAsync untuk menghindari error pending timers pada splash screen
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SplashScreen(),
          ),
        );
        
        // Memastikan teks penting pada SplashScreen dirender
        expect(find.text('WHAT-HER'), findsOneWidget);
        expect(find.text('WEATHER'), findsOneWidget);
        
        // Biarkan timer splash screen selesai (3 detik + buffer)
        await Future.delayed(const Duration(seconds: 4));
        await tester.pump();
      });
    });
  });
}
