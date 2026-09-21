/// Letterbox / pillarbox helpers.
///
/// The implementation lives with [OrthographicProjection] in
/// `projection.dart` because the projection matrix needs to know
/// about it. This file re-exports the public API so callers can
/// import a single letterbox-focused surface.
///
/// See [LetterboxConfig], [computeLetterbox], [computeGutter].
library;

export 'projection.dart' show LetterboxConfig, computeLetterbox, computeGutter;
