const express = require('express');
const { add, subtract, multiply, divide } = require('./calculator');

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ name: 'cicd-practice-app', endpoints: ['/health', '/calculate'] });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', version: process.env.APP_VERSION || '1.0.0' });
});

app.post('/calculate', (req, res) => {
  const { operation, a, b } = req.body;
  try {
    const ops = { add, subtract, multiply, divide };
    if (!ops[operation]) {
      return res.status(400).json({ error: `Unknown operation: ${operation}` });
    }
    const result = ops[operation](a, b);
    res.json({ result });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
}

module.exports = app;
