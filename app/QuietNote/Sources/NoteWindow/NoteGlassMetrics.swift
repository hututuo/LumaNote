import Foundation

struct NoteGlassMetrics {
    let noteOpacity: Double
    let glassStrength: Double
    let minimumNoteOpacity: Double

    init(noteOpacity: Double, glassStrength: Double, minimumNoteOpacity: Double) {
        let normalizedMinimumOpacity = Self.normalized(
            minimumNoteOpacity,
            fallback: AppSettings.minimumNoteOpacity,
            min: 0,
            max: 0.99
        )
        self.minimumNoteOpacity = normalizedMinimumOpacity
        self.noteOpacity = Self.normalized(
            noteOpacity,
            fallback: AppSettings.defaultNoteOpacity,
            min: normalizedMinimumOpacity,
            max: AppSettings.maximumNoteOpacity
        )
        self.glassStrength = Self.normalized(
            glassStrength,
            fallback: AppSettings.defaultGlassStrength,
            min: AppSettings.minimumGlassStrength,
            max: AppSettings.maximumGlassStrength
        )
    }

    var shellMaterialOpacity: Double {
        min(0.69, (0.08 + noteOpacity * 0.40 + glassTextureCurve * 0.12) * opacityEndpointBoost)
    }

    var shellHazeOpacity: Double {
        min(0.191, (0.006 + shellVisibilityCurve * 0.150 + glassTextureCurve * 0.010) * opacityEndpointBoost)
    }

    var shellTintOpacity: Double {
        min(0.085, (0.005 + shellVisibilityCurve * 0.014 + glassTextureCurve * 0.055) * opacityEndpointBoost)
    }

    var shellBorderOpacity: Double {
        min(0.98, 0.18 + shellVisibilityCurve * 0.56 + glassTextureCurve * 0.28)
    }

    var shellVisibilityCurve: Double {
        pow(noteOpacity, 2.4)
    }

    var glassTextureCurve: Double {
        pow(glassStrength, 1.10)
    }

    var islandOpacity: Double {
        max(0.05, noteOpacity)
    }

    var bottomRailOpacity: Double {
        let progress = (noteOpacity - minimumNoteOpacity) / (1 - minimumNoteOpacity)
        let clampedProgress = min(max(progress, 0), 1)
        return 0.075 + clampedProgress * 0.425
    }

    var collapsedChromeOpacity: Double {
        max(0.035, noteOpacity * 0.18)
    }

    private var opacityEndpointBoost: Double {
        1 + shellVisibilityCurve * 0.15
    }

    private static func normalized(
        _ value: Double,
        fallback: Double,
        min lowerBound: Double,
        max upperBound: Double
    ) -> Double {
        let candidate = value.isFinite ? value : fallback
        return Swift.min(Swift.max(candidate, lowerBound), upperBound)
    }
}
