// ignore_for_file: library_prefixes

/// Scoring Configuration Constants
///
/// Centralized configuration for C-Model weather-aware scoring system.
/// Adjust these values to tune the ranking behavior without touching core logic.
library scoring_config;

/// Contribution multipliers for tag roles (semantic, not medical)
const double promotedMultiplier = 1.0; // Strongly encouraged tags
const double neutralMultiplier = 0.4; // Acceptable but not emphasized tags
const double suppressMultiplier = 0.1; // Contextually unsuitable tags

/// Default scoring weights
const double defaultContextWeight = 0.8; // Weather context importance
const double defaultPopularityWeight = 0.2; // Social popularity importance

/// Special case: Neutral weather state weights
///
/// When weather is neutral, contextual relevance is weaker,
/// so we give more weight to popularity (social influence).
const double neutralContextWeight = 0.4;
const double neutralPopularityWeight = 0.6;

/// Random noise range for breaking ties
const double noiseMax = 0.05; // 0.0 ~ 0.05

