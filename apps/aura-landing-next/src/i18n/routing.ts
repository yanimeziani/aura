import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["en", "es", "zh", "hi", "ar", "pt", "fr", "ru"],
  defaultLocale: "en",
  localePrefix: "always",
});
