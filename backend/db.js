// This is a wrapper module that exports the database connection
// It points to the actual database configuration in the config directory
const db = require('./config/database');

module.exports = db;