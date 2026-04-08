const Circle = {
    radius: parseInt(prompt('Enter the radius: ')),

    getArea: function() {
        return Math.PI * this.radius * this.radius;

    },
    getPerimeter: function() {
        return 2 * Math.PI * this.radius;
    },
};

console.log('Radius: ' + Circle.radius);
console.log('Area: ' + Circle.getArea());
console.log('Perimeter: ' + Circle.getPerimeter());
