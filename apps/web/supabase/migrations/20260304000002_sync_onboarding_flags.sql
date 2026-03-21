-- Keep legacy onboarding_complete in sync with onboarding_completed.
-- onboarding_completed is the canonical column moving forward.

UPDATE merchants
SET onboarding_completed = TRUE
WHERE onboarding_complete = TRUE
  AND (onboarding_completed IS DISTINCT FROM TRUE);
