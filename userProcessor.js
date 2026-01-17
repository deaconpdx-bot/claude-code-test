/**
 * User Processor - Complex version (BEFORE refactoring)
 * This function has multiple code smells and complexity issues
 */

function processUserData(u, t, opts) {
  let r = { success: false, data: null, errors: [] };

  if (!u) {
    r.errors.push("No user");
    return r;
  }

  if (t === 1) {
    if (u.age) {
      if (u.age >= 18 && u.age <= 100) {
        if (u.name && u.name.length > 2 && u.name.length < 50) {
          if (u.email) {
            let em = u.email.toLowerCase();
            if (em.includes('@') && em.includes('.')) {
              let pts = 0;
              if (u.age >= 18 && u.age < 25) pts = 100;
              else if (u.age >= 25 && u.age < 35) pts = 200;
              else if (u.age >= 35 && u.age < 50) pts = 150;
              else pts = 75;

              if (opts && opts.bonus) {
                if (opts.bonus === 'premium') pts = pts * 1.5;
                else if (opts.bonus === 'gold') pts = pts * 2;
                else if (opts.bonus === 'platinum') pts = pts * 3;
              }

              let status = '';
              if (pts < 100) status = 'bronze';
              else if (pts >= 100 && pts < 200) status = 'silver';
              else if (pts >= 200 && pts < 300) status = 'gold';
              else status = 'platinum';

              r.success = true;
              r.data = {
                id: u.id || Math.random().toString(36).substr(2, 9),
                name: u.name.trim(),
                email: em,
                age: u.age,
                points: Math.floor(pts),
                status: status,
                type: 'standard'
              };
            } else {
              r.errors.push("Invalid email format");
            }
          } else {
            r.errors.push("Email required");
          }
        } else {
          r.errors.push("Name must be between 3 and 49 characters");
        }
      } else {
        r.errors.push("Age must be between 18 and 100");
      }
    } else {
      r.errors.push("Age is required");
    }
  } else if (t === 2) {
    if (u.companyName && u.taxId) {
      if (u.taxId.length === 9 || u.taxId.length === 10) {
        if (u.email) {
          let em = u.email.toLowerCase();
          if (em.includes('@') && em.includes('.')) {
            let pts = 500;
            if (opts && opts.volume) {
              if (opts.volume === 'high') pts = pts * 1.5;
              else if (opts.volume === 'enterprise') pts = pts * 2.5;
            }

            r.success = true;
            r.data = {
              id: u.id || Math.random().toString(36).substr(2, 9),
              name: u.companyName.trim(),
              email: em,
              taxId: u.taxId,
              points: Math.floor(pts),
              status: 'business',
              type: 'business'
            };
          } else {
            r.errors.push("Invalid email format");
          }
        } else {
          r.errors.push("Email required");
        }
      } else {
        r.errors.push("Tax ID must be 9 or 10 digits");
      }
    } else {
      r.errors.push("Company name and tax ID required");
    }
  } else {
    r.errors.push("Invalid type");
  }

  return r;
}

// Example usage
console.log(processUserData({ name: 'John Doe', email: 'john@example.com', age: 30 }, 1, { bonus: 'premium' }));
console.log(processUserData({ companyName: 'Acme Corp', email: 'contact@acme.com', taxId: '123456789' }, 2, { volume: 'high' }));

module.exports = { processUserData };
