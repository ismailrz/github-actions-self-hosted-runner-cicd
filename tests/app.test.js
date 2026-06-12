const request = require('supertest');
const app = require('../src/app');

describe('API', () => {
  it('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('POST /calculate add', async () => {
    const res = await request(app).post('/calculate').send({ operation: 'add', a: 5, b: 3 });
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(8);
  });

  it('POST /calculate unknown operation returns 400', async () => {
    const res = await request(app).post('/calculate').send({ operation: 'power', a: 2, b: 3 });
    expect(res.status).toBe(400);
  });

  it('POST /calculate divide by zero returns 400', async () => {
    const res = await request(app).post('/calculate').send({ operation: 'divide', a: 5, b: 0 });
    expect(res.status).toBe(400);
  });
});
