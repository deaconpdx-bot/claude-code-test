/**
 * User Processor - Refactored version (AFTER refactoring)
 * Improvements:
 * - Clear, descriptive variable names
 * - Separated concerns (validation, calculation, data transformation)
 * - Constants instead of magic numbers
 * - Reduced nesting with early returns
 * - Reusable validation functions
 * - Better testability
 */

// Constants
const USER_TYPES = {
  STANDARD: 'standard',
  BUSINESS: 'business'
};

const USER_TYPE_IDS = {
  STANDARD: 1,
  BUSINESS: 2
};

const BONUS_MULTIPLIERS = {
  premium: 1.5,
  gold: 2,
  platinum: 3
};

const VOLUME_MULTIPLIERS = {
  high: 1.5,
  enterprise: 2.5
};

const AGE_RANGES = {
  MIN: 18,
  MAX: 100
};

const NAME_LENGTH = {
  MIN: 3,
  MAX: 49
};

const TAX_ID_LENGTHS = [9, 10];

const STATUS_LEVELS = {
  BRONZE: 'bronze',
  SILVER: 'silver',
  GOLD: 'gold',
  PLATINUM: 'platinum'
};

// Validation functions
function isValidEmail(email) {
  if (!email) return false;
  const normalizedEmail = email.toLowerCase();
  return normalizedEmail.includes('@') && normalizedEmail.includes('.');
}

function isValidAge(age) {
  return age && age >= AGE_RANGES.MIN && age <= AGE_RANGES.MAX;
}

function isValidName(name) {
  return name && name.length >= NAME_LENGTH.MIN && name.length <= NAME_LENGTH.MAX;
}

function isValidTaxId(taxId) {
  return taxId && TAX_ID_LENGTHS.includes(taxId.length);
}

// Validation for standard users
function validateStandardUser(user) {
  const errors = [];

  if (!user) {
    errors.push("No user provided");
    return errors;
  }

  if (!isValidAge(user.age)) {
    errors.push(`Age must be between ${AGE_RANGES.MIN} and ${AGE_RANGES.MAX}`);
  }

  if (!isValidName(user.name)) {
    errors.push(`Name must be between ${NAME_LENGTH.MIN} and ${NAME_LENGTH.MAX} characters`);
  }

  if (!user.email) {
    errors.push("Email required");
  } else if (!isValidEmail(user.email)) {
    errors.push("Invalid email format");
  }

  return errors;
}

// Validation for business users
function validateBusinessUser(user) {
  const errors = [];

  if (!user) {
    errors.push("No user provided");
    return errors;
  }

  if (!user.companyName || !user.taxId) {
    errors.push("Company name and tax ID required");
  }

  if (user.taxId && !isValidTaxId(user.taxId)) {
    errors.push(`Tax ID must be ${TAX_ID_LENGTHS.join(' or ')} digits`);
  }

  if (!user.email) {
    errors.push("Email required");
  } else if (!isValidEmail(user.email)) {
    errors.push("Invalid email format");
  }

  return errors;
}

// Points calculation
function calculateStandardUserPoints(age, options) {
  let basePoints = 0;

  if (age >= 18 && age < 25) {
    basePoints = 100;
  } else if (age >= 25 && age < 35) {
    basePoints = 200;
  } else if (age >= 35 && age < 50) {
    basePoints = 150;
  } else {
    basePoints = 75;
  }

  return applyBonusMultiplier(basePoints, options?.bonus);
}

function calculateBusinessUserPoints(options) {
  const basePoints = 500;
  return applyVolumeMultiplier(basePoints, options?.volume);
}

function applyBonusMultiplier(points, bonusType) {
  const multiplier = BONUS_MULTIPLIERS[bonusType] || 1;
  return points * multiplier;
}

function applyVolumeMultiplier(points, volumeType) {
  const multiplier = VOLUME_MULTIPLIERS[volumeType] || 1;
  return points * multiplier;
}

// Status determination
function determineStatus(points) {
  if (points < 100) return STATUS_LEVELS.BRONZE;
  if (points < 200) return STATUS_LEVELS.SILVER;
  if (points < 300) return STATUS_LEVELS.GOLD;
  return STATUS_LEVELS.PLATINUM;
}

// Data transformation
function buildStandardUserData(user, options) {
  const points = calculateStandardUserPoints(user.age, options);

  return {
    id: user.id || generateId(),
    name: user.name.trim(),
    email: user.email.toLowerCase(),
    age: user.age,
    points: Math.floor(points),
    status: determineStatus(points),
    type: USER_TYPES.STANDARD
  };
}

function buildBusinessUserData(user, options) {
  const points = calculateBusinessUserPoints(options);

  return {
    id: user.id || generateId(),
    name: user.companyName.trim(),
    email: user.email.toLowerCase(),
    taxId: user.taxId,
    points: Math.floor(points),
    status: STATUS_LEVELS.GOLD,
    type: USER_TYPES.BUSINESS
  };
}

function generateId() {
  return Math.random().toString(36).substr(2, 9);
}

// Main processing function
function processUserData(user, userTypeId, options = {}) {
  const result = {
    success: false,
    data: null,
    errors: []
  };

  // Validate user type
  if (userTypeId !== USER_TYPE_IDS.STANDARD && userTypeId !== USER_TYPE_IDS.BUSINESS) {
    result.errors.push("Invalid user type");
    return result;
  }

  // Process standard user
  if (userTypeId === USER_TYPE_IDS.STANDARD) {
    const validationErrors = validateStandardUser(user);

    if (validationErrors.length > 0) {
      result.errors = validationErrors;
      return result;
    }

    result.success = true;
    result.data = buildStandardUserData(user, options);
    return result;
  }

  // Process business user
  if (userTypeId === USER_TYPE_IDS.BUSINESS) {
    const validationErrors = validateBusinessUser(user);

    if (validationErrors.length > 0) {
      result.errors = validationErrors;
      return result;
    }

    result.success = true;
    result.data = buildBusinessUserData(user, options);
    return result;
  }

  return result;
}

// Example usage
console.log(processUserData(
  { name: 'John Doe', email: 'john@example.com', age: 30 },
  USER_TYPE_IDS.STANDARD,
  { bonus: 'premium' }
));

console.log(processUserData(
  { companyName: 'Acme Corp', email: 'contact@acme.com', taxId: '123456789' },
  USER_TYPE_IDS.BUSINESS,
  { volume: 'high' }
));

module.exports = {
  processUserData,
  USER_TYPES,
  USER_TYPE_IDS,
  // Export validation functions for testing
  validateStandardUser,
  validateBusinessUser,
  calculateStandardUserPoints,
  calculateBusinessUserPoints
};
