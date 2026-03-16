import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["en-CA", "en-US", "en-AU", "fr-CA", "ar-DZ"],
  defaultLocale: "en-CA",
  localePrefix: "always",
});
