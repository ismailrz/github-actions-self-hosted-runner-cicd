const { add, subtract, multiply, divide } = require('../src/calculator');

describe('calculator', () => {
  describe('add', () => {
    it('adds two positive numbers', () => expect(add(2, 3)).toBe(5));
    it('adds negative numbers', () => expect(add(-1, -2)).toBe(-3));
    it('throws on non-numbers', () => expect(() => add('a', 1)).toThrow(TypeError));
  });

  describe('subtract', () => {
    it('subtracts numbers', () => expect(subtract(5, 3)).toBe(2));
    it('throws on non-numbers', () => expect(() => subtract(1, 'b')).toThrow(TypeError));
  });

  describe('multiply', () => {
    it('multiplies numbers', () => expect(multiply(4, 3)).toBe(12));
    it('handles zero', () => expect(multiply(5, 0)).toBe(0));
  });

  describe('divide', () => {
    it('divides numbers', () => expect(divide(10, 2)).toBe(5));
    it('throws on division by zero', () => expect(() => divide(5, 0)).toThrow('Division by zero'));
  });
});
