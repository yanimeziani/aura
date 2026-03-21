const eslintConfig = [
  {
    ignores: [".next/**", "node_modules/**", "build/**"],
  },
  {
    files: ["**/*.ts", "**/*.tsx"],
    rules: {
      "no-console": "warn",
    },
  },
];

export default eslintConfig;
