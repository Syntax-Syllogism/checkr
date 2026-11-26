const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  collectCoverageFrom: [
    "sfdx-source/checkr/main/ui/lwc/**/*.js",
    "!sfdx-source/checkr/main/ui/lwc/**/__tests__/**"
  ],
  moduleNameMapper: {
    ...jestConfig.moduleNameMapper,
    "^lightning/actions$": "<rootDir>/jest-mocks/lightning/actions",
    "^lightning/refresh$": "<rootDir>/jest-mocks/lightning/refresh"
  },
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  testPathIgnorePatterns: [
    ...(jestConfig.testPathIgnorePatterns || []),
    "<rootDir>/tests/playwright/"
  ]
};
