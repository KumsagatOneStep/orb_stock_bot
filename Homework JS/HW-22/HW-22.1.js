const Laptop = {
    brand: 'Apple',
    model: 'Mac Pro M5',
    price: 2000,

    getInfo: function() {
        return this.brand + ' ' + this.model + ' - $' + this.price;
    }
};

const Phone = {
    brand: 'Samsung',
    model: 'Galaxy',
    price: 1000,


    getInfo: function()  {
        return this.brand + ' ' + this.model + ' -$' + this.price;
    }
};

const Car = {
    brand: 'Merseder',
    model: 'Benz',
    price: 30000,


    getInfo: function()  {
        return this.brand + ' ' + this.model + ' -$' + this.price;
    }
};

console.log(Laptop.getInfo());
console.log(Phone.getInfo());
console.log(Car.getInfo());