//
//  WeatherService.swift
//  Port of the weather helpers at the top of senior/HomeScreen.kt. Android used
//  FusedLocationProviderClient + ACCESS_COARSE_LOCATION; this uses CoreLocation
//  with a reduced-accuracy request, then the same open-meteo endpoint.
//

import Foundation
import CoreLocation
import SwiftUI

struct WeatherData {
    let tempCelsius: Int
    let emoji: String
    let description: String
    let code: Int   // kept so we can look up the gradient
}

func weatherCodeToEmoji(_ code: Int) -> String {
    switch code {
    case 0:             return "☀️"
    case 1, 2:          return "🌤️"
    case 3:             return "☁️"
    case 45, 48:        return "🌫️"
    case 51, 53, 55:    return "🌦️"
    case 61, 63, 65:    return "🌧️"
    case 71, 73, 75:    return "🌨️"
    case 77:            return "🌨️"
    case 80, 81, 82:    return "🌧️"
    case 85, 86:        return "🌨️"
    case 95:            return "⛈️"
    case 96, 99:        return "⛈️"
    default:            return "🌡️"
    }
}

func weatherCodeToDescription(_ code: Int) -> String {
    switch code {
    case 0:          return "Clear sky"
    case 1:          return "Mainly clear"
    case 2:          return "Partly cloudy"
    case 3:          return "Overcast"
    case 45, 48:     return "Foggy"
    case 51, 53, 55: return "Drizzle"
    case 61, 63, 65: return "Rainy"
    case 71, 73, 75: return "Snowy"
    case 77:         return "Snow grains"
    case 80, 81, 82: return "Rain showers"
    case 85, 86:     return "Snow showers"
    case 95:         return "Thunderstorm"
    case 96, 99:     return "Thunderstorm"
    default:         return ""
    }
}

/// Weather code → banner gradient, matching weatherCodeToGradient() on Android.
func weatherCodeToGradient(_ code: Int?) -> [Color] {
    switch code {
    // Clear sky — warm golden sunrise
    case 0: return [Color(hex: 0xFFB347), Color(hex: 0xFF8C00), Color(hex: 0xE65C00)]
    // Mainly clear — soft blue with warm tinge
    case 1: return [Color(hex: 0x87CEEB), Color(hex: 0x4DA6D4), Color(hex: 0x1A78C2)]
    // Partly cloudy — cool blue-gray
    case 2: return [Color(hex: 0x90AFC5), Color(hex: 0x5B8DB8), Color(hex: 0x336699)]
    // Overcast — muted gray
    case 3: return [Color(hex: 0x8E9EAB), Color(hex: 0x6B7B8D), Color(hex: 0x4A5568)]
    // Fog — lavender-gray
    case 45, 48: return [Color(hex: 0xB0BEC5), Color(hex: 0x90A4AE), Color(hex: 0x78909C)]
    // Drizzle — teal-gray
    case 51, 53, 55: return [Color(hex: 0x80CBC4), Color(hex: 0x4DB6AC), Color(hex: 0x26A69A)]
    // Rain — deep blue-slate
    case 61, 63, 65: return [Color(hex: 0x5C6BC0), Color(hex: 0x3949AB), Color(hex: 0x1A237E)]
    // Snow — icy blue-white
    case 71, 73, 75, 77: return [Color(hex: 0xB3E5FC), Color(hex: 0x81D4FA), Color(hex: 0x4FC3F7)]
    // Rain showers — stormy blue
    case 80, 81, 82: return [Color(hex: 0x4FC3F7), Color(hex: 0x0288D1), Color(hex: 0x01579B)]
    // Snow showers — pale blue
    case 85, 86: return [Color(hex: 0xE1F5FE), Color(hex: 0xB3E5FC), Color(hex: 0x81D4FA)]
    // Thunderstorm — dramatic dark purple
    case 95, 96, 99: return [Color(hex: 0x4A148C), Color(hex: 0x311B92), Color(hex: 0x1A0A2E)]
    // Default / loading — original blue-gray
    default: return [Color(hex: 0x78909C), Color(hex: 0x546E7A), Color(hex: 0x37474F)]
    }
}

func fetchWeather(lat: Double, lon: Double) async -> WeatherData? {
    let urlString = "https://api.open-meteo.com/v1/forecast"
        + "?latitude=\(lat)&longitude=\(lon)"
        + "&current=temperature_2m,weathercode"
        + "&temperature_unit=celsius&timezone=auto"
    guard let url = URL(string: urlString) else { return nil }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temp = current["temperature_2m"] as? Double,
              let code = current["weathercode"] as? Int else { return nil }
        return WeatherData(tempCelsius: Int(temp),
                           emoji: weatherCodeToEmoji(code),
                           description: weatherCodeToDescription(code),
                           code: code)
    } catch {
        return nil
    }
}

/// Minimal CoreLocation wrapper — one coarse fix, matching the Android
/// PRIORITY_BALANCED_POWER_ACCURACY request, with the same Toronto fallback.
/// CLLocationManager delivers its callbacks on the thread that created it, and
/// this object is always created on the main actor — hence the @preconcurrency
/// conformance rather than hopping threads in every delegate method.
@MainActor
final class CoarseLocationProvider: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// Returns nil if the fix fails; callers fall back to Toronto like Android did.
    func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        if continuation != nil { return nil }   // a request is already in flight
        return await withCheckedContinuation { cont in
            continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LogManager.logError("Location failed: \(error.localizedDescription)")
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
