// Re-export the shared core through the app module: every existing file's
// unqualified references (Client, Engine, Trends, …) keep resolving with no
// per-file imports, and `@testable import PeakWeek` reaches Core types
// transitively — the whole test suite compiles unchanged.
@_exported import PeakWeekCore

// Foundation also declares a `Unit` class; unqualified lookups in this module
// must keep resolving to ours.
typealias Unit = PeakWeekCore.Unit
