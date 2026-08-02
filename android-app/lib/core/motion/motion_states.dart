enum GenerateMotionState {
  idle,
  readingMaterial,
  extractingKnowledge,
  planningTypes,
  generatingQuestions,
  validating,
  completed,
  failed,
  cancelled,
}

enum PaperBindingState {
  idle,
  grouping,
  numbering,
  layingOut,
  binding,
  openingPreview,
  completed,
  failed,
}

enum ServicePortalState {
  idle,
  opening,
  switching,
  confirming,
  completed,
  failed,
}

extension GenerateMotionStateOrder on GenerateMotionState {
  bool canTransitionTo(GenerateMotionState next) {
    if (next == GenerateMotionState.failed ||
        next == GenerateMotionState.cancelled) {
      return this != GenerateMotionState.completed;
    }
    return next.index >= index;
  }
}
