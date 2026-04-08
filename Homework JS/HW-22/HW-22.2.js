const Calculator = {
    a: 0,
    b: 0,

    read: function() {
        this.a = parseInt(prompt('Enter the number a: '));
        this.b = parseInt(prompt('Enter the number b: '));
    },

    sum: function() {
        return this.a + this.b;
    },
    multiply: function() {
        return this.a * this.b;
    },
}

Calculator.read();
console.log(Calculator.sum());
console.log(Calculator.multiply());